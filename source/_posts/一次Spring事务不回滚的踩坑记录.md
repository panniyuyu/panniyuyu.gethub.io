title: 一次Spring事务不回滚的踩坑记录
author: YyWang
date: 2019-08-16 21:01:13
tags: Spring
categaries: Spring
---
### 一次Spring事务不回滚的踩坑记录

Spring事务不回滚八成是不知道Spring默认在捕获到unchecked异常才会自动回滚，然而我早已踩过个坑，是一个有经验的人，当我自信满满的加上一行 1/0，并在catch中 throw new RuntimeException，debug之后我懵了，咋不回滚呢？重启Tomcat，浏览器缓存清理之后再试一次，还是不行！！！我就难受了，这和我预想的不一样，检查代码没有发现错误，那咋办呢？开始百度吧，百度的结果千篇一律，都是针对不了解Spring默认捕获unchecked异常的解决办法，这些早已在我的经验里了，有3种方法

* 1.手动抛出unchecked异常，让Spring去捕获，然后自动回滚数据
* 2.手动回滚，在发生异常的地方添加代码 **TransactionAspectSupport.currentTransactionStatus().setRollbackOnly();**
* 3.在注解的地方添加配置**rollbackFor = { Exception.class }**，让Spring在捕获到特定的异常自动回滚数据 

3种方法我都知道，但是我一般只用第一种，因为简单，这次我选择用第二种方法试下，竟然没问题了，我意识到是我的问题了，开始检查代码，我的代码逻辑如下（见笑）

```
boolean result = false;
try {
    // ...业务逻辑
    System.out.println(1/0);
    // ...业务逻辑
    result = true;
} catch (Exception e) {
    LOGGER.error(e.getMessage(), e);
    // rollback
    throw new RuntimeException(e);
    result = false;
} finally {
	return result;
}
```

还是不知道错在哪里，没有办法开始Debug，惊奇的发现RuntimeException竟然被忽略了，这才发现我finally中有return，被我自己蠢哭了，基础真是太重要了，我还盲目自信的知道Spring的事务如何使用，到头来连try catch finally都没搞清楚，真是太蠢了。接着我修改了代码：

```
boolean result = false;
try {
    // ...业务逻辑
    System.out.println(1/0);
    // ...业务逻辑
    result = true;
} catch (Exception e) {
    LOGGER.error(e.getMessage(), e);
    // rollback
    throw new RuntimeException(e);
} 
return result;
```

这下确实是回滚了，但是返回值是true，想得到的时false，这又难受了，再次Debug，很多次F6后我明白了，RuntimeException是被Spring框架里的层层代理catch了--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
我把我自己给骗了，RuntimeException抛出程序已经终止了，即使再多的catch最后也不会回到result = true那一行，最终得出原因是其他ajax请求的结果返回到了前台给的提示让我误解了

---

到这里我意识到自己是真的菜，补习一下try catch finally吧
找到[一篇好文](https://blog.csdn.net/mxd446814583/article/details/80355572)

### 总结一下
* 如果finally中有return，try和catch中的return会失效，并且**catch中即使抛出unchecked异常也同样会失效**（这是今天踩的坑）；如果finally中有异常相当于整个方法有了异常，那么就没有最终的返回值了,catch中有了异常同样的效果，所以catch和finally中不要出现异常
* 如果finally中没有return，try和catch中走最先到达return逻辑的地方，并且在return前将返回值暂存，即使finally中修改也不会有效果；（也就是说没有异常最先到达try块中的return，返回值是try块的返回值，catch和finally修改也不会生效；如果try块有异常最先到达catch块中的return，返回值是catch块的返回值，前提是catch块中没有异常，有异常整个方法都没有返回值）
* 综上所述，**使用Spring事务避免不出错优先使用方法2和方法3，方法1比较绕并且对有返回值的逻辑不是很友好；finally块中尽量不要return，这样会忽略try和catch中的异常；最后，基础真的很重要**
