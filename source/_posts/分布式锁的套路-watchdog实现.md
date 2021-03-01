title: 分布式锁的套路-watchdog实现
author: YyWang
tags: Java
categories: Java
date: 2020-10-19 21:38:46 
---

开门见山，分布式锁用来保证分布式环境下业务逻辑的原子性以及互斥，原理就是锁的原理，多个系统一同去竞争同一个资源（类比单机环境下多个线程竞争同一块内存），获得资源的系统可以认为是加锁成功，否则加锁失败；下面总结一个简单可用的分布式锁的实现

### 业务场景
日常开发中，一定会有定时任务操作一些数据的需求，而且这个定时任务还必须要高可用，所以就必须要在分布式环境下运行，但是又不能多个系统一起运行，所以就需要用到分布式锁，能够保证一个系统去运行定时任务，在这个系统出现异常了，其他的系统能够顶上来完成剩下的任务，类似于watchdog的功能

总结了一个流程图如下

![分布式锁](/images/分布式锁.png)

如图所示这个套路，简单无脑，定时任务的时候lock一下，成功了就继续执行，失败了就return，下一个周期再lock；把过期时间设置的比定时任务周期稍微长一些，也就是说当一个系统获取锁成功后，如果没有意外情况后面的周期还是这个系统运行（类比于jvm中的偏向锁，不同的时这个会一直偏不会锁升级），当系统发送异常情况，其他的系统就会lock成功，继续后面的任务，可以完成一个简单高可用的定时任务

### 实现
上面讲过，分布式锁的原理就是能够保证互斥，在一个所有系统都能访问到的地方去做文章，基于这点就有很多种实现，比如数据库这样提供存储的工具(mysql、redis、zk、etcd等等)，理论上所有数据库都可以用来实现分布式锁甚至文件都可以，就看自己的需求了；通常的话使用数据库、redis和zk的比较多

#### mysql
mysql的话是通过数据库的唯一索引保证原子性，首先要创建一个表用于存锁的相关信息，需要一些必填字段

* lockName - 唯一索引，锁的名称
* modifyTime - 修改时间
* owerIp - 获取锁的Ip
* lockTime - 锁的有效时间

```
public boolean lock(lockName, lockTime){
    // 获取当前的锁
	Lock currentLock = lockDao.findLockByLockName(lockName);
	// 当前没有加锁
	if (currentLock == null) {
	    return tryLock(lockName, maxLockTime);//加锁
	}
	//  锁过期了并且成功释放锁 -> 重新加锁，释放锁异常返回false
    if (currentTimeMillis-currentLock.getModifyTime().TimeMills > currentLock.getMaxLockTime()) {
        return unlock(lockName) ? tryLock(lockName, maxLockTime) : false;
    }
    // 锁没过期且自己占有锁且锁没过期 续租
    if (currentLock.getOwnerIP().equals(NetUtils.getLocalHost())) {
        renewLock(currentLock);
        return true;
    }
    return false;
}

public void renewLock(Lock currentLock) {
    try{
        currentLock.setModifyTime(new Date());
        lockDao.update(currentLock);
    }catch(Exception e){
        // 续租失败，但锁没过期，仍然有效
    }
}

public boolean tryLock(String lockName, long maxLockTime) {
    try{
        lockDao.save(new Lock(lockName, NetUtils.getLocalHost(), maxLockTime));
        return true;
    }catch (Exception e){
        return false;
    }
}


public boolean unlock(String lockName) {
    try {
        lockDao.deleteLockByLockName(lockName);
        // 可能存在其他线程把当前线程的锁释放掉，这里可以根据线程的持有者进行释放锁的操作
        // 在我的场景下可以保证定时任务一定会在锁的有效时间内执行完成，故不考虑这种情况
        return true;
    }catch (Exception e) {
        return false;
    }
}
```

#### redis

redis相较于mysql而言吞吐量有了显著的提高，并且也提供了一系列原子操作的api，而且还有过期时间的api不需要，可以很简单的实现分布式锁

```
public boolean lock(lockName, lockTime){
    // 获取当前的锁
	String value = redis.get(lockName);
	// 当前没有加锁
	if (value == null) {
	    return tryLock(lockName, maxLockTime);//加锁
	}
    // redis自己会清理过期的key, 锁没过期且自己占有锁且锁没过期 续租
    if (value.equals(NetUtils.getLocalHost())) {
        renewLock(lockName, period);
        return true;
    }
    return false;
}

public void renewLock(Strng lockName, long period) {
    try{
        // period为定时任务的周期时间，因为lockTime要比period大，每次续期lockTime后锁的过期时间会越来越大
        redis.expire(lockName, redis.ttl(lockName)+period);
    }catch(Exception e){
        // 续租失败，但锁没过期，仍然有效
    }
}

public boolean tryLock(String lockName, long maxLockTime) {
    try{
        return redis.setNx(lockName, NetUtils.getLocalHost(), maxLockTime));
    }catch (Exception e){
        return false;
    }
}


public boolean unlock(String lockName) {
    try {
        lockDao.deleteLockByLockName(lockName);
        return true;
    }catch (Exception e) {
        return false;
    }
}
```

上面给了两种方式的简单实现，实际过程中还需要考虑异常情况的细节，除此以外还有很多种实现的方式只是列举了两种，套用流程图上的套路，实现一个简单的watchdog的功能