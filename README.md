<img title="SUPERCLUSTR" src="logo.svg" height="70" align="left" />

<br />
<br />

---

[https://superclustr.net](https://superclustr.net) — A Computing Cluster for Experimental Internet Research.

Superclustr is a distributed cluster independently created by a group of Internet Researchers and Engineers during their work at the RIPE NCC with the purpose of providing a community run platform for experimental internet research.

> [!NOTE]
> This is a cluster for experimental internet research. If you wish to join the cluster, please contact us via the [Request Access](https://www.superclustr.net/request-access) page. We are looking for a few good people to join the team.


## Enrollment

To enroll your machine into the cluster, please see the examples below.
This will use the latest version of Superclustr to provision your node.

```bash
# Via DHCP
curl -sSL https://archive.superclustr.net/super.sh | bash -s master init \
    --ip-v6-address dhcp \
    --ip-v6-pool 2001:678:7ec:301:8000::/65 \
    --hostname node01.ams.superclustr.net \
    --device ens2f0

# Or, using a Static IP
curl -sSL https://archive.superclustr.net/super.sh | bash -s master init \
    --ip-v6-gateway 2001:678:7ec:301::1 \
    --ip-v6-address 2001:678:7ec:301::2 \
    --ip-v6-pool 2001:678:7ec:301:8000::/65 \
    --hostname node01.ams.superclustr.net \
    --device ens2f0
```

> [!NOTE]  
> We are currently only operating within IPv6 space, therefore all documentation uses this specific protocol version.

You can also find a full example in the [Vagrantfile](Vagrantfile).

## Network Configuration

Here’s the information laid out for our current network configuration.
This is relevant to you if you want to join the cluster or if you want to connect to the cluster from outside.

| **Type**       | **Allocation**                   | **Purpose**                              | **Prefix**                    |
|----------------|----------------------------------|------------------------------------------|-------------------------------|
| **IPv4**       | `89.37.98.1`                     | Gateway                                  | -                             |
|                | -                                | Static IPs for machines                  | -                             |
|                | -                                | MetalLB Address Pool                     | -                             |
| **IPv6**       | `2001:678:7ec:301::1`            | Gateway                                  | -                             |
|                | `2001:678:7ec:301::2 - 2001:678:7ec:301:7fff::` | Static IPs for machines   |  `2001:678:7ec:301::/65`      |
|                | `2001:678:7ec:301:8000:: - 2001:678:7ec:301:ffff::` | MetalLB Address Pool  |  `2001:678:7ec:301:8000::/65` |

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
