import 'package:briani_api/briani_api.dart';

/// True when the transfer is halted and its saved file selection can restart
/// it. qBittorrent 5 reports a paused torrent as stopped rather than paused,
/// so both count. Requests that still need a selection, that failed or
/// stalled (Retry covers those), or that are being removed do not.
bool canResumeDownload(Download download) =>
    (download.transferState == DownloadTransferStateEnum.paused ||
        download.transferState == DownloadTransferStateEnum.stopped) &&
    download.selectedBytes != null &&
    !const [
      DownloadStateEnum.resolving,
      DownloadStateEnum.metadataPending,
      DownloadStateEnum.awaitingSelection,
      DownloadStateEnum.failed,
      DownloadStateEnum.stalled,
      DownloadStateEnum.removing,
      DownloadStateEnum.removed,
    ].contains(download.state);
