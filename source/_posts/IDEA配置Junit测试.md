title: IDEA配置Junit测试
author: YyWang
date: 2019-07-12 15:10:02
tags: IDEA
categories: IDEA
---

看了很多博客后感觉还是比较乱，这篇还不错马一下
*https://blog.csdn.net/hanchao5272/article/details/79197989*

#### 1.安装插件
File->setting->Plugins->搜索并安装Junit Generator 2.0->重启IDEA

#### 2.配置插件
File->setting->	OtherSettings->Junit Generator->properties
+ 修改*Output Path[输出路径]*为*${SOURCEPATH}/../../test/java/${PACKAGE}/${FILENAME}*
+ 修改 Default Template[默认模板]为JUnit4
+ 选中JUnit4页签，将*package test.$entry.packageName;* 修改成*package $entry.packageName;*

#### 3.配置测试的目录
File->Project Structure->Modules中将测试目录设置为Test Source Floder

#### 4.生成测试类
+ 在要测试的类中用快捷键 alt+insert -> Junit Test -> Junit4

#### 5.测试
+ 鼠标右键菜单
	+ 将鼠标光标放在方法相关代码中，右键弹出菜单中会显示运行此测试方法的菜单，点击就会运行方法单独测试。
将鼠标光标放在方法之外的代码中，右键弹出菜单中会显示运行此类的所有测试方法的菜单，点击就会运行所有测试方法。
+ 快捷键
	+ 将鼠标光标放在方法相关代码中，通过快捷键Ctrl+Shift+F10，运行当前测试方法。
	+ 将鼠标光标放在方法之外的代码中，通过快捷键Ctrl+Shift+F10，运行当前类的所有测试方法。
+ 快捷按钮
	+ 点击方法左侧的Run Test按钮，运行当前测试方法。
	+ 点击类左侧的Run Test按钮，运行当前类的所有测试方法。
    
#### 6.测试结果

![upload successful](/images/pasted-12.png)
+ 1.方法测试成功
+ 2.方法测试失败
+ 3.测试用时（毫秒）
+ 4.期望值
+ 5.实际值
+ 6.异常信息

#### 7.异常
+ 
![upload successful](/images/pasted-13.png)
+ 原因：4.11以上版本不在包含hamcrest
+ 解决：改用4.10  ^_^
