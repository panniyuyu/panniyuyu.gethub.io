title: Spring中bean的生命周期总结
author: YyWang
tags: Java
categories: Java
date: 2020-10-09 20:00:44
---

最近非常的忙碌，博客也一直没有更新，可惜自己一直没有时间去看新的东西还想更新博客，心有余而力不足，那就把旧的知识温习一下，来“敷衍”一下；废话不多说，要看spring中bean完整的生命周期要从BeanFactory接口中看，如图，主要分为以下几个部分

* xxxxAware接口的方法
* BeanPostProcessor接口的postProcessBeforeInitialization方法
* InitializingBean接口的afterPropertiesSet方法
* 自定义的init方法
* BeanPostProcessor接口的postProcessAfterInitialization方法

销毁

* DestructionAwareBeanPostProcessor的postProcessBeforeDestruction方法
* DisposableBean接口的destroy方法
* 自定义的销毁方法

![spring-bean生命周期1](/images/spring-bean生命周期1.png)

下面结合源码画一个生命周期图

![spring-bean生命周期2](/images/spring-bean生命周期2.png)