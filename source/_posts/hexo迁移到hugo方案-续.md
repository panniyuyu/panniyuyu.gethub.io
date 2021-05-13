---
title: hexo 迁移到 hugo 方案-续
author: YyWang
date: 2021-05-13 21:16:15
tags: hugo
categories: hugo
---

前面一篇将博客从 hexo 迁移到 hugo 在本地已经跑通了，这篇将跑通的环境打包到云上。

#### 1.将文件上传到 git 仓库

这一步可以说是先做个备份，有几个坑点需要注意，我的地址是 https://github.com/panniyuyu/blog-hugo.git。还有一个原因就是如果没有 git 
执行 hugo server 命令会报错 ERROR 2021/03/05 06:10:33 Failed to read Git log: fatal: not a git repository (or any of the parent directories): .git

* 我使用了 LoveIt 的主题，在 /themes 目录下，需要在 git 仓库中关联子模块，不然的话 git push 不会将主题相关的文件 push 上去的
* 由于要关联子项目，为了不受后续主题仓库的影响，最好先 fork 到自己仓库中一份，子模块引用自己仓库的就可以了

#### 2.创建 Dockerfile

Dockerfile 也很简单了，把大象装冰箱只需要3步，1.找一个 golang 的镜像 2.安装 hugo 3.git clone 第一步上传的文件运行起来

```
FROM golang:1.16

WORKDIR /go/src/

# install hugo
RUN git clone https://github.com/gohugoio/hugo.git --progress --verbose && \
    cd hugo && \
    go install

# init blog
WORKDIR /usr/local/blog

# --recursive 包含子模块一起clone
RUN git clone --recursive https://github.com/panniyuyu/blog-hugo.git --progress --verbose

WORKDIR /usr/local/blog/blog-hugo

CMD sh run.sh 
```

附上 run.sh

```
#!/bin/sh
hugo server -p 1313
```

#### 3.上云

这里我使用的阿里云镜像服务，打好的镜像上传上去再到云服务器上拉下来，然后再把第一步中上传到 git 的仓库拉下来做文件映射，最后运行容器

```
docker run -di -p 1313:1313 -v /usr/local/blog/blog-hugo:/usr/local/blog/blog-hugo --name='blog-hugo' blog-hugo:2021-05-10
```

#### 踩坑

##### 坑1 mac 上宿主机和容器见网络不通

上述步骤完成后，首先再上云之前所有步骤都在本地搞，启动容器之后 curl ${dockerIp}:${port} 是没有反应的，随后进入容器 curl localhost:${port}
这是没问题的有HTML页面，所以问题就出在宿主机和容器网络不通，退出容器在 mac 上 ping 容器的 ip 果然是不通的。mac 端的 docker desktop 默认是
不使用网桥的，所以默认与容器间网络是不通的 [这里](https://docs.docker.com/docker-for-mac/networking/) 有详细的说明，解决方法自行搜索，
我比较懒没有解决，手动狗头

##### 坑2 hugo server 参数

踩到第一个坑以后，跳过本地部署的阶段，直接上云，在运行容器后 ping 容器 ip 网络是通的，即验证了坑1的问题所在，接着进行 curl ${dockerIp}:${port}
 后还是没有响应，进入容器 curl 是正常的，这个坑浪费了很多的时间，其实很简单，就是 hugo server 命令的一个参数指定 hugo 绑定的主机，即默认只有
本地才可以访问，命令如下

```
--bind string            interface to which the server will bind (default "127.0.0.1")
```

##### 坑3 nginx

上面两个坑填完后，之前 hexo 的博客有 Nginx 容器做转发，就计划原有的域名加一个 /hugo 的 path 就可以两个容器都可以用了，还能省下买域名的钱，理
想很丰满，也确实达到了 想要的效果，但是，但是，但是，当我看某一篇文章时，url 是会变的呀，且不说两个容器中文章的 url 格式不一样，就算文章的 url 
配置成一样的，可 Nginx 不知道当前请求是来自 hugo 还是 hexo 怎么转发？或者可以配置公网 ip host 和域名区分，又或者按照有没有 www 前缀来进行转
发，这也太挫了，还是老实买个域名通过主机名路由吧。


#### 最后
    
这三个坑都填上后 hugo 博客就可以用了，再发新的文章就可以直接上传到 git 上（文章在 content/posts/ 目录，图片在 static/images/ 目录），再在
服务器上 git pull 然后 hugo 就热更新了，比 hexo 还需要 docker restart 一下简直太爽了。再展望一下，后续打算 hugo 和 hexo 一起维护，再写文
章就先不写头信息，因为两者头的格式不一样，可以新建一个仓库只写 md 文件，push 到仓库后触发一个 pipeline 将 md 文件添加不同格式的头信息，分别更
新到各个仓库中（这就是 ci），再触发一个 webhook 访问服务器上一个 http 服务，将更新的 hugo 和 hexo 的 文章下载下来，hexo容器需要重启（这步是
cd），这样 cicd 都有了，就做到了全自动，哈哈，后面有时间

  
