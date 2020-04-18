title: IDEA使用笔记
author: YyWang
tags: IDEA
categories: IDEA
date: 2019-07-11 11:22:21
---
#### 配置Tomcat
Run->Edit Configurations->Telplates中配置后在该页面左上角添加->选中Tomcat的Deployment点击部署(选用Artifacts方式)

#### 配置文件取消Unicode编码
File->Setting->搜索file encoding->勾选Transparent native-to-ascii conversion

#### 文件目录变红色



![upload successful](/images/pasted-1.png)
- 解除版本控制即可 file->setting->version control->右上角加号->添加项目目录即可

#### 新建的maven项目没有web项目的目录结构，也没有web.xml

- 增加main目录下增加/webapp/WEB-INF目录
- File->Project Structure->facets->加号->选中目录
- 确认路径depolyment路径为..../webapp/WEB-INF/web.xml
- 确认路径resource路径为 ..../webapp/

**直接创建maven web项目最为简单**

- createProject->maven->勾选Creater from archetype->选择 ***maven-archetype-webapp*** 
- 
![upload successful](/images/pasted-2.png)

#### 右键没有new package

修改目录性质，在该目录右键->Mark Directory as->Source Root

#### 发布方式（参考https://www.cnblogs.com/dpl9963/p/10075456.html）

- jar：Java ARchrive，仅仅是编译好的Java类的聚合
- war：Web application ARchrive，除Java类之外还包含jsp，config等静态资源的聚合
- exploded：理解为展开不压缩，jar和war是压缩的目录节后，exploded表示不压缩的文件目录，开发是用该方式较好，文件更改后不用重新启动服务器看到效果

#### Debug模式

- 快捷键改为eclipse后，F5，F6不变，eclipse的F8变为F9（程序放行）

  

#### 修改文件后没有效果必须重启tomcat  热部署

- runConfigurations中配置
- ![upload successful](/images/pasted-3.png)

#### 部署项目到tomcat上，这里的url一定要改成 /

![upload successful](/images/pasted-11.png)

#### 启动tomcat日志输出乱码 淇℃伅（https://www.cnblogs.com/Yin-BoKeYuan/p/10320622.html）

打开到tomcat安装目录下的conf/文件夹 修改logging.properties文件，
找到 java.util.logging.ConsoleHandler.encoding = utf-8
更改为 java.util.logging.ConsoleHandler.encoding = GBK

#### Java应用热启动配置
方法1.修改之后手动选择 Run->Reload Changed Classes  不能设置快捷键

方法2.我选择使用Jrebel插件，安装重启后要填激活码 ([这里有人搞好了，拿来用^&^](https://www.jiweichengzhu.com/article/33c0330308f5429faf7a1e74127c9708) ) 使用的时候原来是点run或者debug run，现在点旁边两个带jrebel的run和debug run即可

![upload successful](/images/pasted-15.png)

修改代码后 ctrl+F9 快速编译就能查看效果，相当于给方法1加了快捷键

#### import的类不识别，显示红色

这个类是存在的，其他类中引用同样的类就正常，编译无数次还是没解决，缓存问题

解决方法： file -> Invalidate Caches / Restart... -> Invalidate and Restart