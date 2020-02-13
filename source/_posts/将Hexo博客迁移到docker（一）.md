title: 将Hexo博客迁移到docker（一）
author: YyWang
date: 2020-02-13 10:21:32
tags: Docker
categories: Docker
---
本篇是迁移工作的第一阶段

#### docker入门

移步到[这里](http://yywang.top/2020/02/12/Docker%E5%85%A5%E9%97%A8/)

#### 在docker容器中重新搭建Hexo博客系统并记录步骤

拉取centos镜像 -> 启动容器 -> 进入容器bash -> 搭建博客

```
# 拉取镜像
docker pull centos:7
# 启动容器
docker run -di --name=centos7 centos:7
# 进入命令行
docker exec -it centos7 /bin/bash

# 搭建hexo博客

# 安装node.js

# 安装wget
yum install -y wget
# 新建目录 
mkdir /usr/local/nodejs
# 下载tar
wget https://nodejs.org/dist/v12.15.0/node-v12.15.0-linux-x64.tar.xz
# 解压
xz -d node-v12.15.0-linux-x64.tar.xz
# 部署bin文件
ln -s /usr/local/nodejs/node_12.15.0/bin/node /usr/local/bin/node
ln -s /usr/local/nodejs/node_12.15.0/bin/npm /usr/local/bin/npm

# 安装hexo
npm install -g hexo-cli
# 安装git
yum install git-core
# 配置环境变量
ln -s /usr/local/nodejs/node_12.15.0/bin/hexo /usr/local/bin/hexo
# 创建网站文件夹
mkdir myblog
cd myblog
# 初始化hexo
hexo init
hexo generate

# 安装NGINX

# 安装依赖
yum install -y gcc-c++ pcre pcre-devel zlib zlib-devel openssl openssl-devel
# 下载NGINX
wget https://nginx.org/download/nginx-1.16.1.tar.gz
# 解压
tar -zxf nginx-1.16.1.tar.gz
cd nginx-1.16.1
# 编译安装
./configure 
make && make install
# 配置NGINX
vim /usr/local/nginx/conf/nginx.conf
# 启动NGINX
cd /usr/local/nginx/sbin
./nginx
```

其中nginx.conf为

```
	# http中server模块做修改即可
	server {
        listen       80 default_server;
        listen       [::]:80 default_server;
        server_name  _;
        root         /usr/local/myblog/public/;

        # Load configuration files for the default server block.
        include /etc/nginx/default.d/*.conf;

        location / {
        }

        error_page 404 /404.html;
            location = /40x.html {
        }

        error_page 500 502 503 504 /50x.html;
            location = /50x.html {
        }
    }
```
完成上述步骤后开始验证

```
# 将容器保存为镜像
docker commit centos7 mycentos:7.1
# 启动新的容器
docker run -di --name=centos7.1 -p 8088:80 mycentos:7.1 
# 进入容器启动NGINX（从镜像启动容器并没有把NGINX启动）
docker extc -it centos7.1 /bin/bash
# 浏览器中访问 http://${ip}:8088 验证
```

#### 编写dockerfile

根据上述的步骤一步步编写Dockerfile；然后进行 build -> 报错 -> 进入容器查看错误（我太菜了不能看日志直接修改Dockerfile） -> 修改Dockerfile -> build -> ... 直到成功 最终Dockerfile如下

```
FROM centos:7
MAINTAINER yywang sbsbjs@qq.com

# 安装依赖
RUN yum update -y && yum install -y wget git-core vim* gcc-c++ pcre pcre-devel zlib zlib-devel openssl openssl-devel \

# 安装nodejs

# 新建目录 
WORKDIR /usr/local
# 下载tar
RUN wget https://nodejs.org/dist/v12.15.0/node-v12.15.0-linux-x64.tar.xz \
# 解压
&& tar -xvf node-v12.15.0-linux-x64.tar.xz \
&& mv node-v12.15.0-linux-x64 node_12.15.0 \
&& mkdir /usr/local/nodejs \
&& mv node_12.15.0 /usr/local/nodejs/ \
&& rm -rf node-v12.15.0-linux-x64.tar.xz \
# 部署bin文件
&& ln -s /usr/local/nodejs/node_12.15.0/bin/node /usr/local/bin/node \
&& ln -s /usr/local/nodejs/node_12.15.0/bin/npm /usr/local/bin/npm \

# 安装hexo
&& npm install -g hexo-cli \

# 配置环境变量
&& ln -s /usr/local/nodejs/node_12.15.0/bin/hexo /usr/local/bin/hexo \
# 创建网站文件夹
&& mkdir /usr/local/myblog \
&& cd /usr/local/myblog \
# 初始化hexo
&& hexo init \
&& hexo generat \

# 安装NGINX依赖
&& cd /usr/local \
# 下载NGINX
&& wget https://nginx.org/download/nginx-1.16.1.tar.gz \
# 解压
&& tar -zxf nginx-1.16.1.tar.gz \
&& cd /usr/local/nginx-1.16.1 \
# 编译安装
&& ./configure \
&& make && make install \
&& rm -rf /usr/local/nginx-1.16.1 \
&& rm -rf /usr/local/nginx-1.16.1.tar.gz 
```

最后~ 验证

```
# 构建镜像
docker build -t mycentos:7.2
# 启动容器
docker run -di --name=centos7.2 -p 8088:80 mycentos:7.2
# 进入容器修改nginx.conf并启动NGINXß
docker extc -it centos7.1 /bin/bash
# 浏览器中访问 http://${ip}:8088 验证
```
