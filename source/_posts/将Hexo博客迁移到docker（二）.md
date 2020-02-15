title: 将Hexo博客迁移到docker（二）
author: YyWang
tags: docker
categories: docker
date: 2020-02-14 21:33:34
---
本篇将进行迁移的第二阶段，主要步骤为

* 在git上备份博客中的文件
* 进入docker容器中还原
* 验证
* 修改Dockerfile
* 验证

#### 在git上备份博客中的文件

hexo d 是将静态文件发布到git上，内容是 public 文件夹中的文件，hexo g 命令会重新生成静态文件；那么其他文件就是我要转移的文件了，将其他文件备份到git仓库中的新分支中 （.gitignore 里给出存放不需要备份的文件，至于为什么后面慢慢了解，本篇重点不在这） 

```
# 新建分支 hexo
git clone ${git path}
cd username.github.io
git batch hexo
git add .
git commit -m '初次提交'
git push origin hexo
# 删除所有文件 后提交分支
rm -rf *
git add .
git commit -m '删除文件'
git push origin hexo

# 这时候在username.github.io的文件夹下就有了.git文件，将其拷贝的博客目录中
mv .git /usr/local/myblog
cd /usr/local/myblog
git add .
git commit -m '备份博客文件'
git push origin hexo

# 在 themes/next/ 目录下的部分文件没得了，博客里的相册功能依赖这里的文件，需要处理一下
rm -rf /usr/local/myblog/themes/next/.gitignore
cd /usr/local/myblog
git add .
git commit -m 'next主题相关文件'
git push origin hexo
```

到这里已经将自己博客下面的文件都提交到git的hexo分支中了

#### 进入docker容器中还原

```
cd /usr/local
git clone ${git path}
cd /usr/local/${username}.github.io
git checkout hexo
# 由于我已经有myblog的文件夹了这离要删除一下
rm -rf /usr/local/myblog
mv /usr/local/${username}.github.io /usr/local/myblog
# 安装package.json中的依赖
# 修改下载源，安装更快
npm config set registry https://registry.npm.taobao.org
npm install hexo --save
npm install hexo-admin --save
npm install hexo-deployer-git --save
npm install hexo-generator-archive --save
npm install hexo-generator-baidu-sitemap --save
npm install hexo-generator-category --save
npm install hexo-generator-feed --save
npm install hexo-generator-index --save
npm install hexo-generator-search --save
npm install hexo-generator-searchdb --save
npm install hexo-generator-sitemap --save
npm install hexo-generator-tag --save
npm install hexo-helper-live2d --save
npm install hexo-renderer-ejs --save
npm install hexo-renderer-marked --save
npm install hexo-renderer-stylus --save
npm install hexo-server --save
npm install hexo-tag-cloud --save
npm install hexo-wordcoun --save

# 重新生成静态文件
cd /usr/local/myblog
hexo clean
hexo g
hexo d
```
#### 验证

在浏览器中访问 http://${ip}:8088 效果相同即为成功

#### 修改Dockerfile

因为要相册相关要用到python3，镜像中自带的时python2，所以要安装一下python3，在第二阶段的Dockerfile基础上增加下面操作

```
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

# 迁移博客 由于clone速度极其慢，改用本地先clone好复制过去
&& rm -rf /usr/local/myblog
COPY myblog /usr/local/myblog/
# && cd /usr/local \
# && git clone git@github.com:panniyuyu/panniyuyu.github.io.git \
# && cd /usr/local/panniyuyu.github.io \
# && git checkout hexo \
# 由于我已经有myblog的文件夹了这离要删除一下
# && rm -rf /usr/local/myblog \
# && mv /usr/local/panniyuyu.github.io /usr/local/myblog \

# 安装package.json中的依赖
# 修改下载源，安装更快
RUN npm config set registry https://registry.npm.taobao.org \
&& npm install hexo --save \
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
&& npm install hexo-wordcoun --save \

# 重新生成静态文件
&& cd /usr/local/myblog \
&& hexo clean \
&& hexo g

```

#### 验证

启动docker容器 绑定端口映射 8088:80 浏览器访问 http://${ip}:8088 查看效果无误，完成


**最后总结一下需要迁移的步骤**

- git push origin hexo推送博客所有文件
- 编辑Dockerfile
- 在Dokerfile目录下git clone 博客文件 再切换hexo分支 重命名为myblog
- 在Dockerfile目录下编辑nginx.conf文件
- 使用Dockerfile生成镜像
- 启动容器 绑定端口 
- 进入容器启动nginx

是不是迁移起来非常简单，可以将生成的镜像备份成tar包，在任意的服务器上安装docker后，还原镜像启动容器即可


*相册相关*

我的相册是参考[这里](https://malizhi.cn/HexoAlbum/)弄得；我将它移至博客文件的hexo分支，一起备份起来，要上传新的文件运行目录中的tool.py脚本，将照片裁剪后上传至github仓库，这时照片就有了URL，在博客中就可以看到了

*发布博客相关*

* docker容器中的 /usr/local/source/_posts/ 目录下的文件名为乱码，下面方法可以解决，但是我这里没有成功，通过tab补全是正常的ls和ll看就有问题

```
yum -y install convmv

convmv -f GBK -t UTF-8 --notest -r /usr/local/source/_posts/
```

所有我觉得在宿主机建立文件映射，然后进入docker中hexo g -d更新

* hexo d 会失败，这里要重新生成sshkey

```
ssh-keygen -t rsa -C "${email}"
# 拷贝sshkey到github中
# 配置
git config --global user.name "${username}"
git config --global user.email "${email}"  
```
