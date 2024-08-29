# highly available kubernetes cluster for ``niceAmbien.com``

###### TODO: two LB to gain more availability
###### TODO for the DAY-2 ops: replace the Makefile and automate it completely with CICD (gitops way)

### Pre-requisites :

You will need a kcli tool (kubevirt and kvm friendly) to spin up the infrastructure. 
It will be necessary to generate your keys before you start the setup of the control plane and the worker nodes.
We use the ubuntu 22.04 LTS distribution. So, previously, run : 

```bash
    $ kcli download image ubuntu2204
```

We will segregate the control plane and the worker nodes using two subnets, one for each world.

```bash
    $ kcli create network  -c 192.168.50.0/24 net-cp
    $ kcli create network  -c 192.168.150.0/24 net-workers
```

### Infrastructure Installation :

You can touch this target, there after, of your Makefile to do it.

```bash
    $ make infra-up

```

To display all the target, you can do this :

```bash
    $ make help

```

The result has to be like this :

```bash
    $ kcli list vm
    +--------------+--------+-----------------+------------+----------------+-------------+
    |     Name     | Status |        Ip       |   Source   |      Plan      |   Profile   |
    +--------------+--------+-----------------+------------+----------------+-------------+
    | loadbalancer |   up   |  192.168.122.23 | ubuntu2204 | k8s-ha-cluster |    kvirt    |
    |   master1    |   up   |  192.168.50.35  | ubuntu2204 | k8s-ha-cluster | k8s-masters |
    |   master2    |   up   |  192.168.50.245 | ubuntu2204 | k8s-ha-cluster | k8s-masters |
    |   master3    |   up   |  192.168.50.22  | ubuntu2204 | k8s-ha-cluster | k8s-masters |
    |   worker1    |   up   | 192.168.150.117 | ubuntu2204 | k8s-ha-cluster | k8s-workers |
    |   worker2    |   up   |  192.168.150.55 | ubuntu2204 | k8s-ha-cluster | k8s-workers |
    |   worker3    |   up   |  192.168.150.44 | ubuntu2204 | k8s-ha-cluster | k8s-workers |
    +--------------+--------+-----------------+------------+----------------+-------------+

```

### Kubernetes HA cluster setting-up

To install the cluster, you can run this target :

```bash
    $ make setup

```

or ``make setup-lb``, then ``make setup-control-plane`` and then ``make setup-workers``.

Now we run ``make join-workers`` to generate the join command on a control plane node and 
execute it on all specified worker nodes.

:warning: Remember to ensure:

* SSH keys are properly set up for passwordless authentication
* The user **ubuntu** has sudo privileges on all nodes
* Necessary ports are open between nodes (6443 for API server, 10250 for kubelet)


##### kubeconfig file to remotely administrate our cluster

Every master node will have the kubeconfig file into **/etc/kubernetes/** directory. So we need to do :

```shell
    $ scp user@master1:/etc/kubernetes/admin.conf ./kubeconfig
```
to copy it into our client host. It will be necessary to modify the ``server`` stanza of the manifest, with the IP of the load balancer, like this :

```bash
    sed -i 's/server: https:\/\/127.0.0.1:6443/server: https:\/\/your-lb-ip:6443/' ./kubeconfig
```
Now you can run some test againt the cluster with (or without) ``make test``.

### Wordpress deployment

We will use the bitnami helm chart to install the wordpress appli on the cluster. Just touch the target with ``make wp``.
The ``wordpress-value.yaml`` file will be used for customize our deployment.

:warning: This is not production ready, because it lacks security. We need : 

* A proper role-based access control (RBAC).
* Using individual user certificates (rather than sharing the admin kubeconfig!!)
* Implement network policies to restrict API server access.

But... ¡Enjoy!