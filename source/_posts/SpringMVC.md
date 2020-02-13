title: SpringMVC入门
author: YyWang
tags: SpringMVC
catagories: SpringMVC
date: 2019-07-11 15:22:35
---
## SpringMVC配置

*注解&配置文件*

### 注解

#### web.xml

- 
![upload successful](/images/pasted-5.png)

- ①指定Spring配置文件的位置

- ②配置Listener，初始化SpringIOC容器

- ③配置前端控制器servlet，其中可以自定义配置文件位置，不配置默认寻找xxxx-servlet.xml的配置文件

- url-pattern中/和/*区别

  - /*    匹配所有url  有后缀或者无后缀都会匹配   .jsp  .css  .js
  - /      只匹配无后缀的url

  

***注：截图为项目中的配置  自己测试时改为 /  项目中拦截所有页面应该会有拦截器或者过滤器做处理，demo中如果配置成截图这样会报错***

#### springmvc-servlet.xml


![upload successful](/images/pasted-6.png)

- 指定基础包名scan，将指定的包名注入SpringIOC容器（先要添加context的xsd约束）

  - ```
    xmlns:context="http://www.springframework.org/schema/context"
    ```
    xsi中添加 
    "http://www.springframework.org/schema/context       http://www.springframework.org/schema/context/spring-context.xsd"


- exclude-filter 指定类与Spring容器分开加载（先这么理解）

- 配置视图解析器（前缀和后缀）

  

**方法中使用@RequestMapping(value="search")  理解为匹配URL中search的字样**

**方法return "iface/manage";  从匹配的前后缀中寻找应该返回的视图，例如通过上图的配置找到/iface/manage.vm**

*在Controller类上添加@Controller，方法上添加@RequestMapping("xxxx")，即可完成映射*
#### 配置完成访问报错


![upload successful](/images/pasted-7.png)

- 没有jstl标签库，导入依赖即可

- ```XML
  <dependency>  
      <groupId>javax.servlet</groupId>  
      <artifactId>jstl</artifactId>  
  </dependency>
  ```

### 配置文件
#### web.xml
+ 和注解方式一样
![upload successful](/images/pasted-8.png)
#### springmvc-servlet.xml
+ 
![upload successful](/images/pasted-9.png)
+ ①配置处理器映射器
+ ②配置处理器适配器
+ ③配置视图解析器（同注解方式）
+ ④配置映射（相当于注解中的@RequestMapping）

*相较于注解方式该配置文件中多了对 处理器映射器、处理器适配器 以及映射的配置*

*实现方面在controller类中不添加任何注解，实现Controller接口，重写方法即可*
 
demo：https://github.com/panniyuyu/frameworkdemo.git

## 理解
通过使用不同方式对springMVC进行配置，感觉对SpringMVC框架大致的原理有一些认识

SpringMVC使将MVC的模式进一步拆分解耦，整个过程主要包含4个主要的部分依次是 前端控制器（DispatcherServlet）、处理器映射器（HandlerMapping）、处理器适配器（HandlerAdapter）、视图解析器（ViewResolver）

![upload successful](/images/pasted-10.png)
+ 1.用户发起请求，被前端控制器（DispatcherServlet）拦截，并根据请求内容询问处理器映射器（HandlerMapping）改请求应该由哪个Controller处理，处理器映射器将匹配到的Controller信息返回给前端控制器
+ 2.前端控制器知道该请求应该由哪个Controller处理，但不会自己处理，将Controller信息交给处理器适配器（HandlerAdapter）处理，返回ModelAndView对象
+ 3.前端控制器得到ModelAndView对象将其转发给视图解析器，将对象解析成view页面返回
+ 4.前端控制器将view页面相应给浏览器