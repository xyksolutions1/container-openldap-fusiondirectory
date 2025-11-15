# nfrastack/container-openldap-fusiondirectory

## About

This will build a container image for an [OpenLDAP Server](https://sourceforge.net/projects/openldap-fusiondirectory/) with [Fusion Directory](https://www.fusiondirectory.org) Schema's Included. It includes all the functions in the [OpenLDAP Image](https://github.com/nfrastack/container-openldap) such as Multi-Master Replication, TLS, and other features.

## Maintainer

- [Nfrastack](https://www.nfrastack.com)

## Table of Contents

- [About](#about)
- [Maintainer](#maintainer)
- [Table of Contents](#table-of-contents)
- [Installation](#installation)
  - [Prebuilt Images](#prebuilt-images)
  - [Quick Start](#quick-start)
  - [Persistent Storage](#persistent-storage)
- [Environment Variables](#environment-variables)
  - [Base Images used](#base-images-used)
  - [Core Configuration](#core-configuration)
- [Schema Installation](#schema-installation)
- [Maintenance](#maintenance)
  - [Shell Access](#shell-access)
- [Support & Maintenance](#support--maintenance)
- [References](#references)
- [License](#license)

## Installation

### Prebuilt Images

Feature limited builds of the image are available on the [Github Container Registry](https://github.com/nfrastack/container-openldap-fusiondirectory/pkgs/container/container-openldap-fusiondirectory) and [Docker Hub](https://hub.docker.com/r/nfrastack/openldap-fusiondirectory).

To unlock advanced features, one must provide a code to be able to change specific environment variables from defaults. Support the development to gain access to a code.

To get access to the image use your container orchestrator to pull from the following locations:

```
ghcr.io/nfrastack/container-openldap-fusiondirectory:<branch>-(image_tag)
docker.io/nfrastack/openldap-fusiondirectory:<branch>-(image_tag)
```

Image tag syntax is:

`<image>:<optional tag>`

Example:

`ghcr.io/nfrastack/container-openldap-fusiondirectory:2.6-1.5-latest` or

`ghcr.io/nfrastack/container-openldap-fusiondirectory:2.6-1.5-1.0` or

* `latest` will be the most recent commit
* Branch refers to the git branch you are working with and relates to the openldap-fusiondirectory main versiion.
* An otpional `tag` may exist that matches the [CHANGELOG](CHANGELOG.md) - These are the safest.
* If there are multiple distribution variations it may include a version - see the registry for availability.

Have a look at the container registries and see what tags are available.

#### Multi-Architecture Support

Images are built for `amd64` by default, with optional support for `arm64` and other architectures.

### Quick Start

- The quickest way to get started is using [docker-compose](https://docs.docker.com/compose/). See the examples folder for a working [compose.yml](examples/compose.yml) that can be modified for your use.

- Map [persistent storage](#persistent-storage) for access to configuration and data files for backup.
- Set various [environment variables](#environment-variables) to understand the capabilities of this image.

### Persistent Storage

See the upstream [OpenLDAP Image](https://github.com/nfrastack/container-openldap) for this information.

| Directory               | Description                  |
| ----------------------- | ---------------------------- |
| /custom/fusiondirectory | Optional Custom schema files |
### Environment Variables

#### Base Images used

This image relies on a customized base image in order to work.
Be sure to view the following repositories to understand all the customizable options:

| Image                                                        | Description         |
| ------------------------------------------------------------ | ------------------- |
| [OS Base](https://github.com/nfrastack/container-base/)      | Base Image          |
| [OpenLDAP](https://github.com/nfrastack/container-openldap/) | OpenLDAP base image |

Below is the complete list of available options that can be used to customize your installation.

- Variables showing an 'x' under the `Advanced` column can only be set if the containers advanced functionality is enabled.

#### Core Configuration

| Parameter                    | Description               | Default                | Advanced |
| ---------------------------- | ------------------------- | ---------------------- | -------- |
| `FUSIONDIRECTORY_ADMIN_USER` | Default FD Admin User     | `fd-admin`             | x        |
| `FUSIONDIRECTORY_ADMIN_PASS` | Default FD Admin Password | `admin`                | x        |
| `ORGANIZATION`               | Organization Name         | `Example Organization` |          |

## Schema Installation

To install schemas into the LDAP directory, set the appropriate variables in this syntax:

`PLUGIN_<pluginname>=TRUE`

| Variable                             | Description                                                               | Default                           |
| ------------------------------------ | ------------------------------------------------------------------------- | --------------------------------- |
| `FUSIONDIRECTORY_SCHEMA_CUSTOM_PATH` | Store custom schemas that are not included in the image here to be loaded | `/custom/fusiondirectory/schema/` |

Enter inside the container and type `plugin list` for available plugins.
You must have the appropriate schemas installed before using the plugin within FusionDirectory.
If you'd like to reapply the schemas on container startup change `TRUE` to `FORCE`

Recommended Plugins:

| Variable          | Description        | Value  |
| ----------------- | ------------------ | ------ |
| `PLUGIN_AUDIT`    | Audit Trail        | `TRUE` |
| `PLUGIN_DNS`      | Manage DNS         | `TRUE` |
| `PLUGIN_DSA`      | System Accounts    | `TRUE` |
| `PLUGIN_MAIL`     | Mail Attributes    | `TRUE` |
| `PLUGIN_PERSONAL` | Personal Details   | `TRUE` |
| `PLUGIN_PPOLICY`  | Password Policy    | `TRUE` |
| `PLUGIN_SSH`      | Manage SSH Keys    | `TRUE` |
| `PLUGIN_SYSTEMS`  | Systems Management | `TRUE` |

* * *

## Maintenance

### Shell Access

For debugging and maintenance, `bash` and `sh` are available in the container.

## Support & Maintenance

- For community help, tips, and community discussions, visit the [Discussions board](/discussions).
- For personalized support or a support agreement, see [Nfrastack Support](https://nfrastack.com/).
- To report bugs, submit a [Bug Report](issues/new). Usage questions will be closed as not-a-bug.
- Feature requests are welcome, but not guaranteed. For prioritized development, consider a support agreement.
- Updates are best-effort, with priority given to active production use and support agreements.

## References

* https://fusiondirectory.org
* https://openldap.org

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
