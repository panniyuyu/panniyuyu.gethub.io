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
