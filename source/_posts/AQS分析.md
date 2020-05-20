title: AQS分析
author: YyWang
tags: Java
categories: Java
date: 2020-05-20 17:16:07
---

### AQS AbstraceQueuedSynchronizer
* 维护了一个共享变量state（int类型被volatile修饰保证线程的可见性）
* 通过不同线程修改state的状态来决定线程获取锁的状态，并将这些线程维护在一个队列里，每个线程都封装成一个Node对象
* Node中定义了线程的状态 复制表示Node处于有效的等待状态，正值表示Node被取消
	* CANCELLED（1） 当前Node已经取消调度，超时或中断会变更为次状态，进入该状态后的Node不再变化
	* SIGNAL（-1）表示后继Node等待当前Node唤醒，后继Node入队，会修改前驱Node状态为SIGNAL
	* CONDITION（-2）表示Node等待在Condition上，其他线程调用signal()方法后，CONDITION的Node会从等待队列中转移到同步队列，等待获取同步锁
	* PROPAGATE（-3）共享模式下，前驱节点不仅会唤醒后继Node，还可能唤醒后继的后继Node
	* 0 新节点入队时的默认状态
* 定义了独占（Exclusive）和共享（share）两种对state的使用方式

1. 独占 exclusive 只能一个线程操作state；使用 acquire-relase 方法获取和释放资源
   * acquire
     * tryAcquire 根据需要具体实现 尝试获取资源，成功返回true，失败返回false
     * 获取资源失败，将当前线程入队，找到安全点进入等待状态
     * 当被唤醒后判断自己是否是队列中的老二，不是老二找到安全点进入等待状态；是老二尝试获取资源，获取失败继续进入等待状态，等待别唤醒
   * relase
     * tryRelase 根据需要具体实现 尝试释放资源，成功返回true，失败返回false
     * 当资源全部被释放后（state=0，可能被重入state的值大于0）会唤醒队列中的老二来获取资源

![upload successful](/images/acquire-relase.png)

2. 共享 share 多个线程可以同时操作state；使用 acquireShared-relaseShared 方法获取和释放资源
   * acquireShared
	   * tryAcquireShared 根据需要具体实现 尝试获取资源，负数表示失败；正数表示成功，数值表示剩余的资源数量
	   * 获取资源失败，将当前线程入队，入队后如果是老二节点尝试获取资源，老二节点获取资源成功，根据剩余资源量唤醒后面的线程
	   * 不是老二节点或者老二节点获取资源失败，找到安全点进入等待状态，等待被唤醒
   * relaseShared
	   * tryRelaseShared 根据需要具体实现 尝试释放资源，成功返回true，失败返回false
	   * 释放资源成功就去唤醒队列中的老二，老二被唤醒尝试获取资源进入到acquireShared中的第二步

![upload successful](/images/acquireShared-relaseShared.png)

**总结**

AQS其实是一个抽象的基于队列同步器（正如其名称所示，但是并没有使用抽象方法，而是将可扩展的方法默认抛出异常，留给子类去重写覆盖，可能是考虑到单独扩展共享模式或者独占模式，只需实现两个方法即可，不需要全都重写，根据需要选择重写，这样更灵活一些），其中封装了独占模式和共享模式下获取和释放资源的方法，其中没有给出tryAcquire-tryRelase和tryAcquireShared-tryRelaseShared的具体实现，可以根据需要重写这些方法即可，不需要去关心队列中线程的状态变化；比如ReentrantLock就是重写了独占模式中的方法实现；CountDownLatch是重写了共享模式中的方法实现

### ReentrantLock

ReentrantLock中重写了tryAcquire和tryRelase，所有是独占模式，所以ReentrantLock是独占锁并且是可重入的，其中分别有公平和非公平两种实现，默认是非公平的

#### 公平
1. lock() -> acquire(1) 获取锁（修改资源的状态为1）其中使用的时AQS的实现
2. 重写了tryAcquire方法，*如果资源状态是空闲（state=0）并且队列中没有等待资源的线程，才会去获取资源*；如果是当前线程获取资源，直接修改状态并获得锁成功（state += n；可重入；）；其他情况返回false获取资源失败
3. 之后就是AQS中的逻辑 入队、等待被唤醒 balabala...

```
// 公平锁的实现 Sync继承了AQS
static final class FairSync extends Sync {

    final void lock() {
        acquire(1);// 获取资源，调用AQS中的 acquire(1) 方法
    }

    // AQS中的 acquire 方法调用了 tryAcquire 方法，在这里重写执行
    protected final boolean tryAcquire(int acquires) {
        final Thread current = Thread.currentThread();
        int c = getState();
        if (c == 0) {
            // 当前资源空闲并且队列中没有等待资源的线程才会去CAS获取资源
            if (!hasQueuedPredecessors() &&
                compareAndSetState(0, acquires)) {
                setExclusiveOwnerThread(current);
                return true;
            }
        }// 如果是当前线程直接修改资源，返回成功；可重入
        else if (current == getExclusiveOwnerThread()) {
            int nextc = c + acquires;
            if (nextc < 0)
                throw new Error("Maximum lock count exceeded");
            setState(nextc);
            return true;
        }
        eturn false;
    }
}
```

#### 非公平
1. lock -> 抢占锁（CAS修改资源状态） -> 抢锁失败调用acquire(1)获取锁，同样适用AQS的实现
2. 重写了tryAcquire方法，*如果资源状态是空闲（state=0）就CAS修改状态的值获取资源*；如果是当前线程获取资源，修改状态获取资源成功（与公平锁相同，CAS修改state，可重入）；其他情况返回false获取资源失败
3. （相同逻辑）入队、等待被唤醒 balabala...


```
// Sync继承了AQS
static final class NonfairSync extends Sync {
    
    final void lock() {
        // lock的时候抢占一次资源
        if (compareAndSetState(0, 1))
            setExclusiveOwnerThread(Thread.currentThread());
        else
            acquire(1);// 没抢占到调用 acquire 方法（AQS中）
    }
    // AQS中的 acquire 方法调用了 tryAcquire 方法，在这里重写执行
    protected final boolean tryAcquire(int acquires) {
        return nonfairTryAcquire(acquires);// 父类中实现
    }
}

final boolean nonfairTryAcquire(int acquires) {
    final Thread current = Thread.currentThread();
    int c = getState();
    if (c == 0) {// 与公平锁的实现不同，这资源空闲会再抢占一次资源
        if (compareAndSetState(0, acquires)) {
            setExclusiveOwnerThread(current);
            return true;
        }
    }// 与公平锁一样 可重入
    else if (current == getExclusiveOwnerThread()) {
        int nextc = c + acquires;
        if (nextc < 0) // overflow
            throw new Error("Maximum lock count exceeded");
        setState(nextc);
        return true;
    }
    return false;
}
```
#### 总结
1. 公平锁和非公平锁释放资源都使用的父类中的 tryRelase 方法，简单的逻辑，确认当前线程在占用资源后cas修改资源的状态，返回资源是否空闲（state==0?）其他逻辑和AQS中的 relase 相同
2. 可以看到斜体的地方就是公平锁和非公平锁的区别，在资源状态空闲的时候，非公平锁会去抢占资源而公平锁判断队列中没有等待资源的线程才会去获取资源；还有在Acquire之前非公平锁会去抢占一次资源；非公平锁会在lock的时候抢占资源，没有抢到会执行tryAcquire方法，如果此时刚好资源被释放还会去抢占一次资源，都失败了就会入队进入等待状态

### 共享模式的实现

本来想找一个共享模式的实现来分析一下，在AQS中查到实现有这么几个，Semaphore、CountDownLatch和ReentrantReadWriteLock，前两个比较简单来分析一下，后一个比较复杂段时间还搞不定（柿子要挑软的捏是不是？这里再挖个坑吧）

#### Semaphore
Semaphore用来控制线程的并发量，指定并发量就是Semaphore中的许可，拿到许可可以运行，没有拿到许可进入等待状态，有释放的许可唤醒等待的线程，保证线程运行的数量，类似于令牌桶的亚子；其中重写了 tryAcquireShared 和 tryRelaseShared 方法，所以Semaphore是共享模式的实现，同样有公平和非公平两种方式，默认非公平的；

1. acquire 获取许可 -> 调用 acquireSharedInterruptibly 方法，与acquireShared不同的是先判断线程的中断状态，如果中断抛异常，
2. 调用 tryAcquireShared 方法获取资源（公平模式下线判断队列中是否有等待资源的线程，有则返回-1表示失败；没有返回剩余资源数量，获取资源成功；非公平模式下不用判断队列是否有线程直接去获取资源，返回剩余的资源），后面同AQS中的逻辑 


```
// 构造方法初始化AQS的state为permit的数量
public Semaphore(int permits) {
    sync = new NonfairSync(permits);
}
// 转调AQS中 acquireSharedInterruptibly 方法
public void acquire() throws InterruptedException {
    sync.acquireSharedInterruptibly(1);// AQS中的实现
}
public final void acquireSharedInterruptibly(int arg)
        throws InterruptedException {
    if (Thread.interrupted())
        throw new InterruptedException();
    if (tryAcquireShared(arg) < 0)// 这里调用 tryAcquireShared 方法
        doAcquireSharedInterruptibly(arg);
} 
// 非公平模式下转调 nonfairTryAcquireShared 方法
protected int tryAcquireShared(int acquires) {
    return nonfairTryAcquireShared(acquires);
}
final int nonfairTryAcquireShared(int acquires) {
    for (;;) {
        int available = getState();
        int remaining = available - acquires;// 获取资源后的余量
        if (remaining < 0 ||
            compareAndSetState(available, remaining))// 余量大于0 CAS修改状态获取资源成功 否则执行AQS中剩下的逻辑 入队、等待...
            return remaining;
    }
}
// 公平模式下直接重写 tryAcquireShared 方法
protected int tryAcquireShared(int acquires) {
    for (;;) {
        if (hasQueuedPredecessors())// 比非公平模式多了判断队列中是否有等待的线程
            return -1;
        int available = getState();
        int remaining = available - acquires;
        if (remaining < 0 ||
            compareAndSetState(available, remaining))
            return remaining;
    }
}
// relase 方法转调AQS中的 relaseShared 方法
public void release(int permits) {
    if (permits < 0) throw new IllegalArgumentException();
    sync.releaseShared(permits);// 其中调用 tryRelaseShared 方法
}
// 重写 tryRelaseShared 方法(公平非公平相同) 循环CAS改变状态，判断边界范围
protected final boolean tryReleaseShared(int releases) {
    for (;;) {
        int current = getState();
        int next = current + releases;
        if (next < current) // overflow
            throw new Error("Maximum permit count exceeded");
        if (compareAndSetState(current, next))
            return true;
    }
}
```
#### CountDownLatch
CountDownLatch通常用来判断多个线程是否都执行完毕，初始化的时候将AQS中的state设置为等待的线程数量（n），表示资源被n个线程获取；
	
1. await方法转调acquireSharedInterruptibly其中又转调 tryAcquireShared ，返回state是否为0，因为初始化为n所以不为0返回-1，表示获取资源失败将线程入队等待
2. 线程执行完毕后调用countDown方法，转调relaseShared方法将资源的数量减一，当所有线程都调用了countDown此时资源被完全释放（state=0）线程被唤醒，再次 tryAcquireShared 获取state为0返回0，表示获取资源成功，执行后面的逻辑


```
// 构造方法初始化AQS的state为count；Sync继承AQS
public CountDownLatch(int count) {
    if (count < 0) throw new IllegalArgumentException("count < 0");
    this.sync = new Sync(count);
}
// 转调AQS中 acquireSharedInterruptibly 方法
public void await() throws InterruptedException {
    sync.acquireSharedInterruptibly(1);// AQS中的实现
}
public final void acquireSharedInterruptibly(int arg)
        throws InterruptedException {
    if (Thread.interrupted())
        throw new InterruptedException();
    if (tryAcquireShared(arg) < 0)// 这里调用 tryAcquireShared 方法
        doAcquireSharedInterruptibly(arg);
}
// 重写了 tryAcquireShared 方法
protected int tryAcquireShared(int acquires) {
    // state为0返回1表示获取资源成功，不为0返回-1表示获取资源失败
    // 由于刚刚初始化了state=count，假设当前还没有释放资源，state不为0返回-1表示失败，后面就是AQS中的逻辑，入队、等待...
    return (getState() == 0) ? 1 : -1;
}
// countDown 方法转调 relaseShared 方法
public void countDown() {
    sync.releaseShared(1);// AQS中的实现 其中调用了 tryRelaseShared 方法
}
// 重写了 tryRelaseShared 方法，如果state-1之后还不为0返回false表示释放失败，其实是成功的，返回失败是因为还要等待其他线程
// 先不去唤醒等待的线程，当释放资源后state为0返回成功，这时候再去唤醒等待的线程
protected boolean tryReleaseShared(int releases) {
    // 循环CAS操作将state-1
    for (;;) {
        int c = getState();
        if (c == 0)
            return false;
        int nextc = c-1;
        if (compareAndSetState(c, nextc))
            return nextc == 0;
    }
}
```


### 参考文献
[Java并发之AQS详解](https://www.cnblogs.com/waterystone/p/4920797.html)
