title: Docker入门
author: YyWang
tags: 容器
categories: 容器
date: 2020-02-12 17:33:34
---
开门见山，docker是一种新的虚拟化技术，体积小，启动快，减小了开发和运维成本；下面就简单扫个盲入个门

#### 虚拟技术

* 传统的虚拟机技术

![upload successful](/images/pasted-30.png)

它的层次结构为： 个人pc（硬件） -> 操作系统（Host OS） -> 虚拟机管理系统（Hypervisor）-> 虚拟机（VM）

虚拟机中的层次为：操作系统（windos/macos...） -> 依赖库（C++...） -> 应用（tomcat/nginx...）

* docker虚拟技术

![upload successful](/images/pasted-32.png)

它的层次结构为： 个人pc -> 操作系统 -> docker -> 依赖库 -> 容器

容器中的层次接口给为：依赖库（可以复用宿主机的依赖库） -> 应用

* 总结
docker虚拟技术的层级更少，而且还可以复用宿主机的一些文件（依赖库等），所以docker容器的大小比虚拟机要小很多，并且启动也非常快；

除此以外，将自己的应用和环境打包成docker镜像，只要有docker的地方都可以运行相同的容器，不再会有因为环境不同应用运行效果不一样的问题，减小了运维成本

docker虚拟技术更灵活，也可以做到和虚拟机同样的效果

#### docker一些概念

* 镜像 用于创建容器的模板
* 容器 独立运行的一个或一组应用 镜像相当于类，容器相当于类的实例
* 仓库 用于保存镜像，有公有私有两种，类似于git仓库

#### 常用命令

##### 查看版本

```
docker -v
```

##### 修改镜像源

```
vim /etc/docker/daemon.json
```

##### 启动/停止/重启/查看状态

```
systemctl start/stop/restart/status docker
```

##### 查看镜像

```
docker images
```

##### 搜索镜像

```
docker search ${image name}
```

##### 拉取镜像 不指定版本号拉去最新的

```
docker search pull ${image name}:${version}
```

##### 删除镜像 -f 强制删除

```
docker rmi -f ${image name/id}
```

##### 查看正在运行的容器 -a(查看所有)

```
docker ps -a
```

##### 容器运行相关参数

* -i：表示运行容器
* -t：表示容器启动进入命令行   交互式容器 exit退出命令行，容器也退出（守护式容器不会退出）
* --name：为创建的容器命名
* -v：表示目录映射关系（前者是宿主机目录，后者是映射到宿主机上的目录）
* -d: 守护模式容器
* -p: 表示端口映射 前者宿主机端口 后者容器内映射端口
* -e: 指定环境变量

##### 启动交互式容器

```
docker run -it --name=${name} ${image name}:${version} /bin/bash
```

##### 启动守护式容器

```
docker run -di --name=${name} ${image name}:${version}
```

eg:

```
docker run -di --name=mysql_test -p 3316:3306 -e MYSQL_ROOT_PASSWORD=root centosz:7
```

##### 进入容器

```
docker exec -it ${container name} /bin/bash
```

eg:

```
docker exec -it mysql_test /bin/bash
```

##### 启动/停止容器

```
docker start/stop ${container name/id}
```

##### 宿主机和容器文件互拷

宿主->容器

```
docker cp ${file} ${container name}:${path}
```

容器->宿主 要在宿主机中使用命令行

```
docker cp ${name}:${file} ${path}
```

##### 目录挂载

```
docker run -di -v ${source path}:${target path} --name=${container name} ${image name}:${version}
```

##### 查看容器ip

```
docker inspect ${container name/id}
```

##### 删除容器

```
docker rm ${container name/id}
```

##### 将容器保存为镜像

```
docker commit ${container name} ${inage name}
```

##### 将镜像保存为tar包

```
docker save -o ${tar name}.tar ${path}
```

##### 恢复镜像

```
docker load -i ${tar name}.tar
```

##### 停止全部容器

```
docker stop $(docker ps -q)
```

##### 删除全部容器

```
docker rm $(docker ps -aq)
```

##### 停止并删除全部容器

```
docker stop $(docker ps -q) & docker rm $(docker ps -aq)
```


#### dockerfile 创建镜像

简单来说记录一系列命令和参数，然后docker根据dockerfile中的命令来构建镜像

##### From 

从哪个基础镜像进行构建

##### MAINTAINER 

镜像创建者

##### ENV key value 

设置环境变量

##### RUN command 

运行shell指令（多个RUN会有多层嵌套，不期望使用多个RUN，多个指令以 \ 结尾 && 开头）

##### ADD source_file dest_file 

将宿主文件复制到容器内，压缩文件自动解压

##### COPY source_file dest_file 

将宿主文件复制到容器内，压缩文件不自动解压

##### WORKDIR path 

设置工作目录，相当于 cd

##### 构建镜像命令

```
docker build -t ${image name}:${tag} .
```