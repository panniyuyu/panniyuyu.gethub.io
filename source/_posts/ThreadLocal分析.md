title: ThreadLocal分析
author: YyWang
tags: Java
categories: Java
date: 2020-05-19 21:08:37
---

废话不说，直接开整，上源码

Java中每个Thread类中都有属于自己的私有map（ThreadLocalMap key是ThreadLocal的弱引用），不同线程之间的map是私有的相互隔离

```
public class Thread implements Runnable {
    ...
    ThreadLocal.ThreadLocalMap threadLocals = null;
    ...
}
```

### set方法

1. 计算hash值，找到table中对应的位置，key是null直接放入，key相同替换，key冲突后向后查找直到找到可以插入的地方
  * 从这个插入的方式可以看出，table中的桶对应一个entry，与HashMap中的链表或者红黑树不同，而且到达3/4的容量就会扩容，所以不会存在，桶中有链表或者红黑树的数据结构
2. 插entry后 cleanSomeSlot  从当前插入entry的位置，往后扫描找key为null的entry，找logn次（who tell me 这是 why？）找到key为null的entry（可能1个可能多个） expungeStaleEntry(i) 方法清理
  * expungeStaleEntry(i) 清理从i开始往后到下一个entry是null之间的位置
3. 如果找到key为null的entry，并且经过清理之后tab的数量还大于扩容的阈值，调用 rehash 方法扩容
  * expungeStaleEntries() 清理整个table中key是null的entry，清理之后tab的size大于扩容的阈值 进行 resize （扩容的逻辑）

```
public void set(T value) {
    Thread t = Thread.currentThread();
    ThreadLocalMap map = getMap(t);
    if (map != null)
        map.set(this, value); // 进入这里
    else
        createMap(t, value);
}
private void set(ThreadLocal<?> key, Object value) {
    Entry[] tab = table;
    int len = tab.length;
    int i = key.threadLocalHashCode & (len-1);

    for (Entry e = tab[i];
         e != null;
         e = tab[i = nextIndex(i, len)]) {
        ThreadLocal<?> k = e.get();
			  // key相同替换 返回
        if (k == key) {
            e.value = value;
            return;
        }
        // key为null替换 返回
        if (k == null) {
            replaceStaleEntry(key, value, i);
            return;
        }
    }
    // 找到entry为null的位置插入
    tab[i] = new Entry(key, value);
    int sz = ++size;
    // cleanSomeSlots清理一部分entry后size还大于阈值进行扩容
    if (!cleanSomeSlots(i, sz) && sz >= threshold)
        rehash();
}
    
// 如函数名所说，清理一部分Solts（key为null的entry），具体的说清理从i到下一个entry是null之间的部分
private boolean cleanSomeSlots(int i, int n) {
    boolean removed = false;
    Entry[] tab = table;
    int len = tab.length;
    do {
        i = nextIndex(i, len);// 从i开始往下遍历，遍历logn次
        Entry e = tab[i];
        if (e != null && e.get() == null) {// 找到key是null的entry
            n = len;
            removed = true;
            i = expungeStaleEntry(i);// 清理从i开始到entry为null的位置 并且对key不为null的entry做rehash 代码就不贴了
        }
    } while ( (n >>>= 1) != 0);// 每次n/2 遍历logn次
    return removed;
}
```

### get方法
1. 调用threadLocalMap中的getEntry方法，通过hash值找到tab中的位置，当前位置没找到调用 getEntryAfterMiss 方法
2. getEntryAfterMiss 从当前位置往后找到key的entry返回

```
public T get() {
Thread t = Thread.currentThread();
ThreadLocalMap map = getMap(t);
if (map != null) {
    ThreadLocalMap.Entry e = map.getEntry(this);// 进入这里看看
    if (e != null) {
        @SuppressWarnings("unchecked")
        T result = (T)e.value;
        return result;
    }
}
return setInitialValue();// map为空set初始值
}
	
private Entry getEntry(ThreadLocal<?> key) {
    int i = key.threadLocalHashCode & (table.length - 1);
    Entry e = table[i];
    if (e != null && e.get() == key)
        return e;
    else
        return getEntryAfterMiss(key, i, e); // hash后的位置没找到key
}
  
// 从当前位置向后找 过程中遇到key为null的 entry 调用expungeStaleEntry(i)进行清理
private Entry getEntryAfterMiss(ThreadLocal<?> key, int i, Entry e) {
    Entry[] tab = table;
    int len = tab.length;

    while (e != null) {
        ThreadLocal<?> k = e.get();
        if (k == key)
            return e;
        if (k == null) // 遇到key是null的entry进行清理
            expungeStaleEntry(i);// 与set过程中调用同一方法，清理从i到下一个key为null节点之间的位置
        else
            i = nextIndex(i, len);
        e = tab[i];
    }
    return null;
}
```

### 内存溢出问题
* ThreadLocal的结构如图所示，因为new ThreadLocal对象，所有栈中有ThreadLocal的强引用，而ThreadLocalMap中key是ThreadLocal的弱引用，如果将ThreadLocal对象置为null，则ThreadLocal只有弱引用指向它，当下次gc的时候key会被回收掉

![upload successful](/images/ThreadLocal.png)

* 如果当前线程没有退出，value依然有强引用指向它，所以value并不会被回收，虽然经过分析源码使用get和set方法会清理map中的key为null的一部分节点清理掉，但是在调用get和set之前仍然存在oom的风险
* 最稳妥的就是使用remove方法，将不需要的ThreadLocal清理掉
* 不要和线程池一起使用，线程池中的线程是复用的，永远不会被销毁，所以线程中的ThreadLocalMap也不会被清理，如果这个线程一直不被使用或者不在调用get和set方法，这块内存永远不会被回收

### 挖坑
* 根据nextIndex方法里的实现来看，这个结构是一个环形结构

```
private static int nextIndex(int i, int len) {
    return ((i + 1 < len) ? i + 1 : 0);
}
```		
* [参考文献](https://mp.weixin.qq.com/s/vURwBPgVuv4yGT1PeEHxZQ)中所说，hash算法使用黄金分割数，大大降低了hash冲突的几率，具体怎么降低的先挖个坑后面再填

### 参考文献
[一篇文章彻底了解ThreadLocal的原理 ](https://mp.weixin.qq.com/s/vURwBPgVuv4yGT1PeEHxZQ)
