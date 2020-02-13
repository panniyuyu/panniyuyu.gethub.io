title: Optional 使用及源码
author: YyWang
tags: Java8
categories: Java8
date: 2019-08-15 20:58:37
---
### Optional 使用及源码分析
A container object which may or may not contain a non-null value.

可能包含空值的容器对象。

怎么理解呢？就把它当成是和Collection一样的容器，Collection是通过不同的数据结构和API来操作容器中的元素；Optional则是提供API来判断容器中的元素是否为空，在此基础上还能根据是否为空的不同结果给出自定义的处理逻辑。这么说还是很抽象，直接上源码就会好理解一些。

#### 成员变量

```
// 空的Optional对象
private static final Optional<?> EMPTY = new Optional<>();
// 容器中元素的值
private final T value;
```

这个value是容器中元素的值，怎么理解呢，使用Optional是要通过它的API进行判空来达到避免NPE的现象，上面说到将Optional当成是一个容器，这个容器中的元素则是需要判空的对象，也就是说容器中的元素就是你传入的参数，这个value就是传参的值

#### 构造方法
无参构造，只是将value置为null

```
private Optional() {
        this.value = null;
}
```

有参构造

```
private Optional(T value) {
    this.value = Objects.requireNonNull(value);
}
```

其中返回Objects中的requireNonNull的方法，再看这个方法

```
public static <T> T requireNonNull(T obj) {
    if (obj == null)
        throw new NullPointerException();
    return obj;
}
```

很简单如果obj为空抛出异常，不为空返回本身，所以有参构造的效果就是确认value不为空并给value赋值，如果是空就抛异常

而且这两个构造函数是私有的，也就是说我们不能new出来

#### 主要方法
* empty()--返回空的Optional对象

```
public static <T> Optional<T> empty() {
    Optional var0 = EMPTY;
    return var0;
}
```
* of(T var1)--调用了有参构造，即有值返回带有该值得Optional对象，为空则会抛异常

```
public static <T> Optional<T> of(T var0) {
    return new Optional(var0);
}
```

* ofNullable(T var0)--元素为null返回空的Option对象，不是null返回本身

```
public static <T> Optional<T> ofNullable(T var0) {
    return var0 == null ? empty() : of(var0);
}
```

* get()--从名字就可以看出是获取元素的值，也就是返回value，如果是null的话会抛异常

```
public T get() {
    if (this.value == null) {
        throw new NoSuchElementException("No value present");
    } else {
        return this.value;
    }
}
```

* isPresent()--返回value是否为null

```
public boolean isPresent() {
    return this.value != null;
}
```

* ifPresent(Consumer<? super T> var)--如果元素不是空的话执行var1中的逻辑，Consumer之前有文章写过，是接收一个参数执行一个没有返回值得逻辑

```
public void ifPresent(Consumer<? super T> var1) {
	if (this.value != null) {
	    var1.accept(this.value);
	}
}
```

* filter(Predicate<? super T> var1)--首先确保predicate对象和value不是null，然后用predicate对象对value进行筛选，满足条件返回本身，不满足条件返回空的对象（看源码是这个意思，具体怎什么情况用还想不到~）

```
public Optional<T> filter(Predicate<? super T> var1) {
    Objects.requireNonNull(var1);
    if (!this.isPresent()) {
        return this;
    } else {
        return var1.test(this.value) ? this : empty();
    }
}
```

* map(Function<? super T, ? extends U> var1)--同样确保var1不是null，之后value为空值返回空的Optional对象，value有值执行var1中的逻辑

```
public <U> Optional<U> map(Function<? super T, ? extends U> var1) {
    Objects.requireNonNull(var1);
    return !this.isPresent() ? empty() : ofNullable(var1.apply(this.value));
}
```

* flatMap(Function<? super T, Optional< U >> var1)--与map方法相同,不同的是入参，根据不同的参数结构使用不同的方法

```
public <U> Optional<U> flatMap(Function<? super T, Optional<U>> var1) {
    Objects.requireNonNull(var1);
    return !this.isPresent() ? empty() : (Optional)Objects.requireNonNull(var1.apply(this.value));
}
```

* T orElse(T var1)--获取value的值，不为空返回本身，为空返回入参var1

```
public T orElse(T var1) {
    return this.value != null ? this.value : var1;
}
```

* T orElseGet(Supplier<? extends T> var1)--与orElse的逻辑一样，不同的是value为空返回的是supplier对象的逻辑

```
public T orElseGet(Supplier<? extends T> var1) {
    return this.value != null ? this.value : var1.get();
}
```

* T orElseThrow(Supplier<? extends X> var1)--同样的逻辑，不同的是value为null会抛异常

```
public <X extends Throwable> T orElseThrow(Supplier<? extends X> var1) throws X {
    if (this.value != null) {
        return this.value;
    } else {
        throw (Throwable)var1.get();
    }
}
```

#### 总结

* of和ofNullable
  * 都是取值，如果元素是null的话of会报空指针--不用，ofNullable将null转为空的对象没有空指针；
  * get方法同样是取值，value是null也会抛异常--不用
  * 最后，取值用ofNullable就完事了
* isPresent和ifPresent
  * isPresent返回元素是否为null，有返回值
  * ifPresent元素不为空执行一段逻辑，无返回值
  * 最后，只判断用isPresent有逻辑用ifPresent
* filter、map和flatMap
  * 都是将不是null的元素执行传入的逻辑，根据不同的需求选择方法
* orElse、orElseGet和orElseThrow
  *  都是将null的元素做转换，orElse返回传入的值，orElseGet返回传入的逻辑，这两个方法看需求没有逻辑有orElse有逻辑用orElseGet；orElseThrow元素为null抛异常--不用

#### 栗子

刚刚学习还不知道怎么使用，看到[一篇文章]（https://www.cnblogs.com/rjzheng/p/9163246.html） 给的栗子不错，很有借鉴意义，但是我对这篇文章中的orElse和orElseGet的栗子有不同意见。

##### 栗子1

* 使用前

```
public String getCity(User user)  throws Exception{
    if(user!=null){
        if(user.getAddress()!=null){
            Address address = user.getAddress();
            if(address.getCity()!=null){
                return address.getCity();
            }
        }
    }
    throw new Excpetion("取值错误"); 
}
```

* 使用后

```
public String getCity(User user) throws Exception{
    return Optional.ofNullable(user)
                   .map(u-> u.getAddress())
                   .map(a->a.getCity())
                   .orElseThrow(()->new Exception("取指错误"));
}
```

##### 栗子2

* 使用前

```
if(user!=null){
    dosomething(user);
}
```

* 使用后

```
 Optional.ofNullable(user)
         .ifPresent(u->{
            dosomething(u);
         });
```

##### 栗子3

* 使用前

```
public User getUser(User user) throws Exception{
	if(user!=null){
	    String name = user.getName();
	    if("zhangsan".equals(name)){
	        return user;
	    }
	}else{
	    user = new User();
	    user.setName("zhangsan");
	    return user;
	}
}
```

* 使用后

```
public User getUser(User user) {
    return Optional.ofNullable(user)
                   .filter(u->"zhangsan".equals(u.getName()))
                   .orElseGet(()-> {
                        User user1 = new User();
                        user1.setName("zhangsan");
                        return user1;
                   });
}
```