#!/usr/bin/env python3
"""Run a headless, test-only VLC decode probe against an M06 playback URL.

Host mode validates the owned M06 network, then launches one disposable VLC
tool container. Container mode reads the mounted protected URL file and emits
only URL-free version and decoded-frame evidence.
"""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import time
import urllib.parse
import uuid


IMAGE = "briani-vlc-proof:dev"
URL_PATH_IN_CONTAINER = "/tmp/media-url"
RESULT_PATH_IN_CONTAINER = "/artifacts/result.json"


def docker(*args: str) -> str:
    result = subprocess.run(["docker", *args], check=False, text=True,
        stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if result.returncode:
        raise RuntimeError(f"docker {args[0]} failed ({result.returncode})")
    return result.stdout.strip()


def validate_media_url(raw: str) -> urllib.parse.SplitResult:
    if len(raw) > 4096 or "\n" in raw or "\r" in raw:
        raise ValueError("protected URL file must contain one bounded URL")
    parsed = urllib.parse.urlsplit(raw)
    if parsed.scheme != "http" or parsed.hostname != "briani" or parsed.query or parsed.fragment:
        raise ValueError("URL must target the owned Briani HTTP media alias")
    if not re.fullmatch(r"/stream/[A-Za-z0-9_-]{43}/[^/]{1,512}", parsed.path):
        raise ValueError("URL path is not a scoped playback stream")
    return parsed


def media_probe(url_file: Path, output_dir: Path, timeout: int) -> dict:
    output_dir.mkdir(parents=True, exist_ok=True)
    url_text = url_file.read_text(encoding="utf-8").strip()
    validate_media_url(url_text)

    import vlc

    package_version = getattr(vlc, "__version__", "unknown")
    runtime_version = vlc.libvlc_get_version().decode("ascii", "replace")
    print("vlc-stage: creating-instance", flush=True)
    instance = vlc.Instance("--intf=dummy", "--vout=dummy", "--aout=dummy",
        "--no-video-title-show", "--no-osd", "--quiet", "--network-caching=1000")
    if instance is None:
        raise RuntimeError("VLC could not initialize its test-only dummy output instance")
    media = instance.media_new(url_text)
    player = instance.media_player_new()
    player.set_media(media)
    start = time.monotonic()
    try:
        print("vlc-stage: calling-play", flush=True)
        if player.play() == -1:
            raise RuntimeError("VLC refused to start the scoped HTTP media")
        print("vlc-stage: play-returned", flush=True)
        frame_values = {"decoded_video": 0, "displayed_pictures": 0}
        state_name = "opening"
        last_progress = 0.0
        while time.monotonic() - start < timeout:
            state = player.get_state()
            state_name = getattr(state, "name", str(state))
            stats = vlc.MediaStats()
            if media.get_stats(stats):
                for field in frame_values:
                    frame_values[field] = int(getattr(stats, field, getattr(stats, "i_" + field, 0)) or 0)
            if frame_values["decoded_video"] > 0 or frame_values["displayed_pictures"] > 0:
                return {
                    "result": "first_frame_decoded",
                    "firstFrameSeconds": round(time.monotonic() - start, 3),
                    "vlcRuntimeVersion": runtime_version,
                    "pythonVlcVersion": package_version,
                    "playerState": state_name,
                    **frame_values,
                    "output": "dummy",
                    "physicalDisplayCertified": False,
                }
            elapsed = time.monotonic() - start
            if elapsed - last_progress >= 2:
                print(f"vlc-progress: seconds={elapsed:.1f}; state={state_name}; "
                      f"decoded_video={frame_values['decoded_video']}; "
                      f"displayed_pictures={frame_values['displayed_pictures']}", flush=True)
                last_progress = elapsed
            if state_name.lower() in ("ended", "error"):
                raise RuntimeError("VLC ended before decoding video")
            time.sleep(.2)
        raise TimeoutError(
            f"no decoded video frame within {timeout}s; state={state_name}; "
            f"decoded_video={frame_values['decoded_video']}; "
            f"displayed_pictures={frame_values['displayed_pictures']}"
        )
    finally:
        player.stop()
        player.release()
        media.release()
        instance.release()


def owned_api_alias(network_name: str, run_id: str) -> None:
    info = json.loads(docker("network", "inspect", network_name))[0]
    labels = info.get("Labels") or {}
    if not info.get("Internal") or labels.get("org.briani.test") != "M06" or labels.get("org.briani.run") != run_id:
        raise ValueError("network is not the labeled internal M06 network for this run")
    found = False
    for container_id in (info.get("Containers") or {}).keys():
        container = json.loads(docker("inspect", container_id))[0]
        container_labels = container.get("Config", {}).get("Labels") or {}
        if container_labels.get("org.briani.test") != "M06" or container_labels.get("org.briani.run") != run_id:
            continue
        nets = container.get("NetworkSettings", {}).get("Networks") or {}
        aliases = nets.get(network_name, {}).get("Aliases") or []
        if container_labels.get("org.briani.role") == "api" and "briani" in aliases:
            found = True
    if not found:
        raise ValueError("no run-owned API container has the briani network alias")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--network", help="owned internal M06 Docker network")
    parser.add_argument("--run-id", help="exact org.briani.run label on the network and API")
    parser.add_argument("--url-file", type=Path, help="mode-0600 file containing the scoped stream URL")
    parser.add_argument("--artifacts", type=Path, required=True, help="directory for URL-sanitized JSON and logs")
    parser.add_argument("--timeout", type=int, default=30, help="wall-clock limit, 1 to 30 seconds")
    parser.add_argument("--image", default=IMAGE, help="local test-only VLC image tag")
    parser.add_argument("--container-probe", action="store_true", help=argparse.SUPPRESS)
    args = parser.parse_args()
    if not 1 <= args.timeout <= 30:
        parser.error("--timeout must be between 1 and 30 seconds")

    if args.container_probe:
        try:
            result = media_probe(Path(URL_PATH_IN_CONTAINER), Path("/artifacts"), args.timeout)
            result["packageVersions"] = Path("/usr/share/vlc-proof-packages.txt").read_text(encoding="utf-8").splitlines()
            Path(RESULT_PATH_IN_CONTAINER).write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
            print(json.dumps(result, sort_keys=True))
            return 0
        except Exception as error:
            result = {"result": "failed", "failure": type(error).__name__, "detail": str(error)}
            # Exception messages are kept free of the URL before they reach logs or artifacts.
            result["detail"] = re.sub(r"https?://[^\s]+", "[redacted-url]", result["detail"])
            Path(RESULT_PATH_IN_CONTAINER).write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
            print(json.dumps(result, sort_keys=True))
            return 1

    if not args.network or not args.run_id or not args.url_file:
        parser.error("host mode requires --network, --run-id, and --url-file")
    if not re.fullmatch(r"[0-9a-fA-F-]{32,36}", args.run_id):
        parser.error("--run-id must be the exact UUID used by the M06 harness")
    url_file = args.url_file.expanduser().resolve()
    file_stat = url_file.stat()
    if file_stat.st_uid != os.getuid() or file_stat.st_mode & 0o777 != 0o600:
        parser.error("URL file must be owned by this user and have mode 0600")
    validate_media_url(url_file.read_text(encoding="utf-8").strip())

    run_id = uuid.uuid4().hex
    output_dir = args.artifacts.expanduser().resolve() / run_id
    output_dir.mkdir(parents=True, mode=0o700)
    output_dir.chmod(0o700)
    container_name = "briani-m06-vlc-" + run_id[:12]
    result_path = output_dir / "result.json"
    log_path = output_dir / "player.log"
    try:
        owned_api_alias(args.network, args.run_id)
        image_id = docker("image", "inspect", "--format", "{{.Id}}", args.image)
        command = ["docker", "run", "--rm", "--name", container_name,
            "--network", args.network,
            "--label", "org.briani.test=M06", "--label", f"org.briani.run={args.run_id}",
            "--user", "1000:1000", "--read-only", "--cap-drop=ALL", "--security-opt=no-new-privileges",
            "--pids-limit=128", "--memory=512m", "--cpus=2",
            "--tmpfs", "/tmp:rw,noexec,nosuid,size=64m",
            "--mount", f"type=bind,source={url_file},target={URL_PATH_IN_CONTAINER},readonly",
            "--mount", f"type=bind,source={output_dir},target=/artifacts",
            # Leave room for the container to write an honest player-state
            # timeout artifact before the outer wall-clock guard fires.
            args.image, "--artifacts", "/artifacts", "--timeout", str(max(1, args.timeout - 3))]
        try:
            completed = subprocess.run(command, check=False, text=True, stdout=subprocess.PIPE,
                stderr=subprocess.PIPE, timeout=args.timeout)
        except subprocess.TimeoutExpired as expired:
            # A killed Docker client can leave its container running; remove only
            # this uniquely named, run-labeled probe container.
            try:
                docker("kill", container_name)
            except RuntimeError:
                pass
            try:
                docker("rm", "-f", container_name)
            except RuntimeError:
                pass
            partial_stdout = getattr(expired, "stdout", "") or ""
            partial_stderr = getattr(expired, "stderr", "") or ""
            if isinstance(partial_stdout, bytes):
                partial_stdout = partial_stdout.decode("utf-8", "replace")
            if isinstance(partial_stderr, bytes):
                partial_stderr = partial_stderr.decode("utf-8", "replace")
            safe_stdout = re.sub(r"https?://[^\s]+", "[redacted-url]", partial_stdout)
            safe_stderr = re.sub(r"https?://[^\s]+", "[redacted-url]", partial_stderr)
            log_path.write_text((safe_stdout + "\n" + safe_stderr)[-12000:], encoding="utf-8")
            raise TimeoutError(
                f"VLC probe exceeded its {args.timeout}s wall-clock limit; "
                "last safe player diagnostics are in player.log"
            )
        # VLC or a loader diagnostic can echo the media URI; redact all URLs before saving output.
        stdout = re.sub(r"https?://[^\s]+", "[redacted-url]", completed.stdout)
        stderr = re.sub(r"https?://[^\s]+", "[redacted-url]", completed.stderr)
        log_path.write_text((stdout + "\n" + stderr)[-12000:], encoding="utf-8")
        container_result = {}
        try:
            container_result = json.loads(stdout.strip().splitlines()[-1])
        except (ValueError, IndexError):
            pass
        result = {"result": container_result.get("result", "failed"), "runId": run_id,
            "m06RunId": args.run_id, "image": args.image, "imageId": image_id,
            "player": container_result, "log": str(log_path)}
        result_path.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"result": result["result"], "runId": run_id, "evidence": str(result_path)}))
        return 0 if completed.returncode == 0 and result["result"] == "first_frame_decoded" else 1
    except Exception as error:
        detail = re.sub(r"https?://[^\s]+", "[redacted-url]", str(error))
        result_path.write_text(json.dumps({"result": "failed", "runId": run_id,
            "failure": type(error).__name__, "detail": detail}, indent=2) + "\n", encoding="utf-8")
        print(json.dumps({"result": "failed", "runId": run_id, "failure": type(error).__name__, "evidence": str(result_path)}))
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
