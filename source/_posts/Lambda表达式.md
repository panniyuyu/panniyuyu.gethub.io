title: Lambda表达式
author: YyWang
date: 2019-08-05 09:06:59
tags: Java8
catagories: Java8
---
#### 语法
包含3个部分：参数 -> 表达式/代码块
+ (params) -> expression
+ (params) -> statement
+ (params) -> { statements }

**与内部类相同，lambda表达式不可以修改外部变量，这点与匿名内部类相同，不同的是lambda表达式不用将变量显示的声名为final，如果是在自己的作用域中定义局部变量可以进行修改，最终保证线程安全**

**（踩坑）lambda表达式中的this并不是代表当前使用lambda表达式的对象，而是外部类的对象**

#### 作用 
##### 可代替匿名内部类
+ 可以代替只包含一个抽象方法的接口，也叫做函数式接口，例如；Comparator、Runnable
+ Java8内置了四大函数式接口分别为：Consumer，Supplier，Function，Predicate
+ jdk8中提供@FunctionalInterface 注解来检查接口是否符号函数式接口的标准

##### 可代替迭代操作
+ list.forEach(n -> {});
 
##### 通过Stream操作集合
+ list.stream().filter()...collect();

##### 对数据处理
+ 与Spark相似java8可以将集合转化为流（Stream），在对流进行map和reduce操作，与Spark相同这些方法也是惰性求值的

#### Java8的函数式接口
##### 消费型接口 Consumer<T>
+ 抽象方法-void accept(T t);
+ 参数类型-T
+ 返回类型-void

这个还没有用过，因为返回值为空并且传递一个参数，我感觉和集合的遍历差不多 list.forEach(n -> sout(n)); 通过定义多个Consumer对象相当于定义多个逻辑块，最终consumer1.addThen(consumer2) 连接，也就是说consumer1逻辑完成后执行consumer2（为什么不写在一个逻辑里呢？我猜可能需要解耦吧）
 
##### 供给型接口 Supplier<T>
+ 抽象方法-T get();
+ 参数类型-无参数
+ 返回类型-T
+ 
这个感觉很简单，没有参数但要返回一个值，可能new一个对象的时候会用到吧，声名Supplier对象后直接调用get执行定义的逻辑（箭头后面的逻辑）返回一个值
 
##### 函数型接口 Function<T,R>
+ 抽象方法-R apply(T t)
+ 参数类型-T
+ 返回类型-R
 
同样是创建Function对象定义一个方法逻辑，接口中有Consumer接口同样的实现方法andThen，用法也相同，不同的是Function定义中有返回值，fun1.addThen(fun2)是将fun1执行的返回值传入fun2中再执行fun2中的逻辑，除此之外该接口还有一个实现方法compose，用法和andThen相反，fun1.compose(fun2) 是先执行fun2中的逻辑将返回值作为参数传入fun1中再执行fun1中的逻辑

##### 断言型接口 Predicate<T>
+ 抽象方法-boolean test(T t)
+ 参数类型-T
+ 返回类型-boolean
+ 定义的Predicate对象相当于筛选条件的对象，最终通过stream中的filter进行过滤，多个条件可以用and和or来进行组合相当于运算符 && 和 ||
+ 多用做集合筛选 eg:
+ 
```
// 筛选大于18岁的女性用户
Predicate<User> matchAge = u -> u.age > 18;
Predicate<User> matchSex = u -> u.sex.equals("f");
resultList = userList.stream().filter(matchAge.and(matchSex)).collect(Collectors.toList());
```
我的理解是在定义Predicate的对象时，-> 前传入参数， -> 后定义test的方法体，最终补充抽象方法test，通过stream的filter筛选相当于将集合中的每个元素都调用一次test方法，将返回值为true的筛选出来。
