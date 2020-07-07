title: 我又来入门k8s了
author: YyWang
tags: k8s
categories: Java
date: 2020-06-30 22:49:30
---

### 引言
之前分析过Docker容器技术，在容器技术很快的被广大使用之后，对于业务复杂的公司来说往往需要非常多的容器，而每次都需要docker run或者restart的话也是非常麻烦的而且人操作的话还容易出错，这就需要一个容器管理的一个组件，比如docker swarm、mesos和k8s，最终k8s脱颖而出称为大多数人的选择，而且k8s还被称为PaaS平台的操作系统，那么k8s能做什么呢？

Pod，是k8s提出的概念，是k8s的最小调度单位，Pod中可以有一个容器或者多个容器

* Pod调度；k8s采用声明式API的方式，用户只需编写yaml文件描述所期望的Pod状态(比如2个容器，4c8g)，k8s根据所期望的Pod状态进行部署和维护
* 健康检查自动恢复；监控集群中Pod的状态发现异常Pod进行迁移或重启
* 动态扩缩容；检查Pod负载高时动态扩容进行负载均衡；反之减少容器节省资源
* 负载均衡

类似于Pod的运维系统，有了这些功能完全可以将自己的系统托管给k8s，可以减轻运维人员的工作

### 架构
master+slave的架构，master节点负责系统逻辑的处理，调度，slave节点来干活，与spark集群的模式是一样的

* master节点组件
	* etcd：分布式kv数据库，用于保存数据(yaml文件)和集群的状态，其他组件都通过api server向etcd读写数据，理解为用来保存状态的数据层；etcd还是高可用的分布式数据库可以保证master的高可用
	* api server：提供api服务，负责各个模块之间的通信，不同组件之间交互都需要经过api server，理解为数据总线
	* controller manager：负责维护集群的状态，确保集群的状态与etcd中的状态保持一致，理解为MVC中的Controller层；例如健康检查，slave节点中的kubectl会向master节点(通过api server)定期报告节点中Pod的状态，相当于slave向master发心跳，心跳状态会保存在etcd中，master节点中的controller manager会定期从etcd中获取slave的状态，针对这些状态与etcd中保存的期望状态比对进行下一步操作，通过api server通知scheduler组件创建一个调度任务发送给slave节点
	* scheduler：负责调度，将pod调度到合适的node中；创建pod资源的时候，通过etcd中的状态调度到合适的slave节点中，更新或者删除也是这样
* slave组件
	* kubelet：可以理解为通过实现了一些接口来对slave节点进行管控操作；负责与master通信，通过CRI(Container Runtime Interface)操作容器运行时(container runtime)，相当于是slave节点中的控制器，理解为通过CRI"发送指令"到容器运行时，对当前节点中pod做CRUD操作；还负责配置当前slave节点的网络和存储，通过调用网络插件和存储插件为容器配置网络（CNI Container Networking Interface）和持久化存储（CSI Container Storage Interface）；
	* kube-proxy：用于service的服务发现和负载均衡，通过iptable机制；service是相同服务的的多个pod集合，相当于一个VIP职责，不需要关心具体服务的ip只需访问服务的域名，由kube-proxy来转发到具体的pod
	* container runtime：真正对pod做CRUD操作的组件，相当于kubelet的slave

![k8s](/images/k8s.png)

如上图在slave节点中kubelet扮演控制器的角色来操作通过进行时对Pod进行操作，而kube-proxy是将访问pod的流量转发到相应的pod中，一个pod在启动之前k8s会在pod中先启动一个初始容器为这个容器添加Namespace，network，Volume这些设置，再将后启动的容器添加到初始容器的Namespace中去，这个初始容器用来进行进程隔离，与Pod具有相同的生命周期，通常Pod中容器的访问，日志收集等操作都会由这个容器来完成，也就是sidecar容器；访问某个pod的时候首先会经过iptables的规则转发到Pod的sidecar容器里，再由sidecar容器转发到目标应用容器中，sidecar可以天然用来做微服务中的流量控制，服务治理，灰度发布等功能

工作原理

* 用户提交了yaml文件给apiserver
* apiserver会将数据保存到etcd中，再通知scheduler有容器需要被调度
* scheduler根据配置选择合适的node，返回给apiserver
* apiserver将结果同步到etcd中，再通知对应node中的kubectl
* kubectl收到通知后调用container runtime来真正去启动这个配置的容器，调用storage plugin配置存储，调用network plugin配置网络

### API
* Pod；Pod是k8s的最小调度单位，Pod中可以有一个容器或者多个容器；前面分析过docker是通过Namespace和Cgroup技术来进行进程的隔离，是基于单进程模型并不具备管理多进程的能力，（参考[这里](https://zhuanlan.zhihu.com/p/83482791)大概是是无法回收僵尸进程和孤儿进程的资源的意思因为回收进程资源需要向父进程发送一个信号）；k8s通过将多个容器加入到同一个Namespace中并给头号进程赋予了管理多进程的能力，所以说相较于docker容器来说k8s的Pod概念更像是虚拟机一样，提供了传统虚拟机到容器环境的完美迁移方案
* Deployment；对Pod的一个抽象，可以定义Pod的副本数量，版本，可以用Deployment来描述一个应用集群的状态
* ReplicaSet；用来控制Pod的版本，Deployment不会之间控制Pod，而是通过ReplicaSet来间接控制Pod，一个Pod的版本对应一个RS（可以实现金丝雀发布，蓝绿发布）
* StatefulSet；有状态的Pod进行编排；Pod之间有拓扑关系的拓扑状态或者存储状态；
* DaemonSet；集群中运行一个DaemonPod，每个Node中有且只有一个，如果有新节点加入集群会自动创建；比如node中的各种插件（网络，存储，监控，日志）
* Service；提供了一个或者多个Pod的访问地址，由于Pod的地址可能会变，通过域名可以做到不依赖于固定的ip地址访问Pod，相当于VIP，由kube-proxy+iptables来共同实现
* Job；一次性任务，运行完成后退出
* CronJob；定时任务，用于离线计算
* 等等等等，只是了解到了这些，还有很多去查看官方文档吧

	