title: 将Hexo博客迁移到docker中（究极解决方案）
author: YyWang
date: 2020-04-19 08:47:36
tags: Docker
categories: Docker
---

前两个阶段是两个月前的试验版本，只是在本机上用docker模拟并没有真正做迁移，然而在真正迁移的过程中，虽然可以完整迁移，但是体验不友好，我改进了迁移方案，首先总结一下缺点吧

* 启动容器后需要进入容器中，启动nginx做转发
* 如果不使用也需要进入容器中启动hexo，且不能退出否则hexo也会跟着退出
	* 后台启动需要依赖pm2这个工具
	* 后台启动hexo和nginx会不会有资源争抢的问题，这个应该没有纯属给自己加戏
* 修改文章后即使做了文件挂载也需要进入容器中重新生成静态文件

图解一下，原来的方案和现在的方案

![upload successful](/images/pasted-33.png)

可以看到原来是塞到一个docker容器中的，中间的图是现在的架构，将nginx和hexo拆分，分别放入docker中，nginx的docker转发请求到hexo的docker，hexo的docker需要运行hexo s；未来如果我有新的网站可以重新部署一个容器通过nginx做转发，比如，不同域名转发到不同的容器，或者我再搞一个WordPress版本的docker，还可以做金丝雀发布，ab测试。哈哈

下面开始动手

#### 先从nginx开始

```
# 直接拉取nginx镜像
docker pull nginx
# 修改配置文件运行 把配置文件做目录挂载 绑定80端口
docker run -di nginx --name nginx -v /usr/local/temp/nginx.conf:/etc/conf/nginx/nginx.conf -p 80:80 nginx
# 之后配置有变化修改 nginx.conf 后 docker restart 即可

```

#### hexo

与之前的版本不同的是，我要在容器启动的时候就把hexo运行起来，每次修改文件后docker restart就能重新生成静态文件并启动hexo

坑点

* 刚开始我再dockerfile中添加命令 CMD['hexo','s']
* 编译好的镜像run了之后并没有启动，查看状态run了之后就退出了
* 我的第一反应是不是要后台启动才可以，随即有尝试使用 pm2 后台启动，修改命令CMD['pm2','start','run.js']
* 还是不行呢，冷静下来发现不管是hexo还是pm2都是nodejs中的命令，而dockerfile中运行的应该是sh脚本
* 于是转换思路 dockerfile中启动shell脚本，脚本中运行hexo 修改命令 CMD ["/usr/local/myblog/buildbak/run.sh"]
* 还有一个小坑，运行起来会报没有权限的错误 再添加命令赋权 重新build就完成了 chmod 777 /usr/local/myblog/buildbak/run.sh

run.sh 很简单，每次clean后重新生成静态文件再启动hexo，这样每次新增或者修改博客的时候restart就好了

```
#!/bin/sh
cd /usr/local/myblog;
hexo clean;
hexo g;
hexo s
```

完整dockerfile

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
# 修改npm源
&& npm config set registry https://registry.npm.taobao.org \
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

# 安装依赖
RUN yum update -y && yum install -y zlib-devel bzip2-devel openssl-devel ncurses-devel sqlite-devel readline-devel tk-devel gcc make \
# 备份原始的python
&& mv /usr/bin/python /usr/bin/python.bak \
# 下载解压
&& cd /usr/local \
&& wget https://www.python.org/ftp/python/3.6.2/Python-3.6.2.tar.xz \
&& tar -xvJf  Python-3.6.2.tar.xz \
# 编译安装
&& cd Python-3.6.2 \
&& ./configure prefix=/usr/local/python3 \
&& make && make install \
&& rm -rf /usr/local/Python-3.6.2.tar.xz \
# 添加软链
&& ln -s /usr/local/python3/bin/python3 /usr/bin/python3 \
&& ln -s /usr/local/python3/bin/pip3 /usr/bin/pip3 \
# 安装依赖
&& pip3 install Pillow \
# 迁移博客 由于clone速度极其慢，而且还需要添加git秘钥，改用本地先clone好复制过去
&& rm -rf /usr/local/myblog
COPY myblog /usr/local/myblog/

# 安装package.json中的依赖
# 修改下载源，安装更快
RUN npm install hexo --save \
&& npm install hexo-admin --save \
&& npm install hexo-deployer-git --save \
&& npm install hexo-generator-archive --save \
&& npm install hexo-generator-baidu-sitemap --save \
&& npm install hexo-generator-category --save \
&& npm install hexo-generator-feed --save \
&& npm install hexo-generator-index --save \
&& npm install hexo-generator-search --save \
&& npm install hexo-generator-searchdb --save \
&& npm install hexo-generator-sitemap --save \
&& npm install hexo-generator-tag --save \
&& npm install hexo-helper-live2d --save \
&& npm install hexo-renderer-ejs --save \
&& npm install hexo-renderer-marked --save \
&& npm install hexo-renderer-stylus --save \
&& npm install hexo-server --save \
&& npm install hexo-tag-cloud --save \
&& npm install hexo-wordcount --save \

# 重新生成静态文件
&& cd /usr/local/myblog \
&& hexo clean \
&& hexo g \
&& chmod 777 /usr/local/myblog/buildbak/run.sh
# 环境搭建完成，启动脚本
CMD ["/usr/local/myblog/buildbak/run.sh"]
```

build好镜像后，运行容器

```
docker run -di -v /usr/local/temp/myblog/source/_posts/:/usr/local/myblog/source/_posts/ -v /usr/local/temp/myblog/source/images/:/usr/local/myblog/source/images/ --name myblog -p 22000:4000 myblog:final
```

启动起来后查询dockerip

```
docker inspect --format='{{.NetworkSettings.IPAddress}}' myblog
```

修改nginx.conf 将请求转发到docker的4000端口，重启nginx容器，完美结束

每次修改或者新增文件，重启hexo容器即可，最后别忘了提交文件到github中做备份 

后续

* 将Dockerfile nginx.conf run.sh 复制到myblog中，提交到github中做备份
* 将最终的镜像上传至阿里云
* 如果容器没有变化迁移环境的话直接，从阿里云拉取镜像运行即可
* 如果内容变化就要先提交最新状态到github中，在新的环境中clone仓库，重新build镜像运行即可
