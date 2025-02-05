<img title="SUPERCLUSTR" src="logo.svg" height="70" align="left" />

<br />
<br />

---

[https://superclustr.net](https://superclustr.net/?ref=github) — A distributed computing cluster for early research

Superclustr is a distributed cluster independently created by a group of Internet Researchers and Engineers
from the RIPE NCC with the purpose of providing a community operated platform for early research.

> [!NOTE]
> This is an experimental service and not operated by or affiliated with the RIPE NCC. If you wish to join the operated cluster, please contact us via the [Request Access](https://www.superclustr.net/request-access) page. We are looking for a few good people to join the team.


## Enrollment

To enroll in the cluster, you can use the following command.
It will download the latest version of the Superclustr CLI and provision your node.

```bash
# Via DHCP
curl -sSL https://archive.superclustr.net/super.sh | bash -s master init \
    --ip-pool 89.37.98.6/27 \
    --ip-address dhcp \
    --ip-v6-pool 2001:678:7ec:70::100/120 \
    --ip-v6-address dhcp \
    --hostname node01.ams.superclustr.net \
    --device ens2f0

# Or, using a Static IP
curl -sSL https://archive.superclustr.net/super.sh | bash -s master init \
    --ip-gateway 89.37.98.1 \
    --ip-address 89.37.98.2 \
    --ip-netmask 255.255.255.128 \
    --ip-pool 89.37.98.6/27 \
    --ip-v6-gateway 2001:678:7ec:70::1 \
    --ip-v6-address 2001:678:7ec:70::2 \
    --ip-v6-pool 2001:678:7ec:70::100/120 \
    --hostname node01.ams.superclustr.net \
    --device ens2f0
```

You can also find a full example in the [Vagrantfile](Vagrantfile).

## Network Configuration

Here’s the information laid out for our current network configuration.
This is relevant to you if you want to join the cluster or if you want to connect to the cluster from outside.

| **Type**       | **Allocation**              | **Purpose**                       | **Range**                         | **CIDR**                     |
|-----------------|-----------------------------|------------------------------------|------------------------------------|------------------------------|
| **IPv4**       | `89.37.98.1`                | Gateway                           | `89.37.98.1`                      | -                           |
|                | `89.37.98.2 - 89.37.98.5`   | Static IPs for machines           | `89.37.98.2, .3, .4, .5`          | -                           |
|                | `89.37.98.6 - 89.37.98.37`  | MetalLB Address Pool              | `89.37.98.6 - 89.37.98.37`         | `89.37.98.6/27`             |
| **IPv6**       | `2001:678:7ec:70::1`        | Gateway                           | `2001:678:7ec:70::1`              | -                           |
|                | `2001:678:7ec:70::2 - ::5`  | Static IPs for machines           | `::2, ::3, ::4, ::5`              | -                           |
|                | `2001:678:7ec:70::100 - ::1ff` | MetalLB Address Pool              | `::100 - ::1ff`                   | `2001:678:7ec:70::100/120` |

## Getting Started

Follow these instructions to get the project up and running on your local machine.

### Prerequisites

Before you begin, ensure you have the following installed on your system:

-   [Docker](https://docs.docker.com/get-docker/)
-   [Docker Compose](https://docs.docker.com/compose/install/)
-   [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)

### Clone the Repository

First, clone the repository to your local machine:

```sh
git clone git@github.com:robin-rpr/bgpdata.git
cd bgpdata
```

### Building

To build the binary, run the following command:

```sh
make
```

## Testing

```bash
vagrant plugin install vagrant-vmware-desktop
```

```bash
vagrant up
```

```bash
vagrant destroy -f
```

## Projects

-   [bgpdata](https://github.com/robin-rpr/bgpdata) — BGP Data Collection and Analytics Service
-   [cernide](https://github.com/robin-rpr/cernide) — Integrated Development Environment for Machine Learning Research
-   [ris-kafka](https://github.com/robin-rpr/ris-kafka) — Unofficial Kafka Broker for the RIPE NCC's Routing Information Service (RIS)

Have a project you want to add to the list? [Request Access](https://www.superclustr.net/request-access)

## License

See [LICENSE](LICENSE)
