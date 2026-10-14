# Development foundation

The shipped server uses Docker Compose. Native server execution is for automated
local development tests only. Production manifests require an audited Briani
image digest; no default secret or moving application image is supplied.

The native Arch SDK is 10.0.112; the official container SDK is 10.0.401. Both
use .NET runtime 10.0.12. `global.json` explicitly permits the tested stable
feature-band roll-forward. NuGet dependency versions and resolved hashes are
locked. Windows/macOS native binaries and Pi performance require their own runners.

Use `python tools/dev.py doctor`, `build`, `test --suite unit`,
`test --suite contract`, `test --suite integration`, and `client --task analyze`.
The sandbox may prevent sockets or Flutter's filesystem wrapper; these checks
must run in an authorized local environment. No administrator/group changes
are made by the runner. Android Studio is optional. Flutter-generated Gradle
wrapper/tooling is versioned under `client/android`; inspect local SDK images
before selecting an AVD. An emulator is not a physical TV hardware certificate.

API client generation: `python tools/contracts/generate.py` and
`python tools/contracts/generate.py --check`. Download the pinned generator JAR
from Maven Central into `.tools/openapi`; its exact checksum is checked by the
script. Generated unused-import/private-field lint annotations are deterministic
and restricted to generated files. Two enum identifiers use metadata `byName`
for wire value `name`, avoiding a built_value reserved-member collision. No wire
field or enum value changed.

Container build: `docker --config .tools/docker-config buildx build --load -t
briani-server:dev -f infra/images/server.Dockerfile .`. The project-scoped Buildx
plugin does not change the host's Docker groups or global configuration. An
ARM64/amd64 manifest can be built with the same recipe on the matching CI runners;
missing native hardware remains blocked verification.

All state/data roots must be mounted with the configured UID/GID writable.
Create new empty state directories for a test project; do not use a personal
library or restore a test backup into production. Production egress firewall
policy and integration onboarding are developed in their later milestones.
