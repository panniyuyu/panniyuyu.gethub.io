title: 一次MySQL死锁的踩坑记录
author: YyWang
tags: MySQL
categories: MySQL
date: 2020-11-17 14:23:43
---

我又写bug了，O(∩_∩)O哈哈~，这次是MySQL数据库的死锁，真实太菜了🤷‍♀️(日常一菜)

### 背景

* 我在实现一个接口，使用动态配置中心的API，创建配置并发布，因为要保证接口的幂等性，我为了方便每次将配置删除并重新创建再发布，相较于先查询所有的配置，判断当前配置不存在后再创建的方法，我觉着会多了判断的逻辑消耗，所以采用了第一种方式： 调用删除配置的api接口清空历史数据 -> 创建新的配置 -> 发布新的配置
* 接下来介绍一下动态配置中心的背景，创建的配置保存在config_item表中，发布的配置将config_item表中的数据插入到config_item_release表中，两个表的结构是一样的，主要信息粘一下，发布配置是以profile维度(就理解为配置的路径)，所以会有profile_id+key的唯一索引；

```
config_item和config_item_release
(
  id bigint not null comment '主键id' primary key,
  profile_id bigint not null comment 'profile id',
  `key` varchar(200) not null comment '配置项key',
  value varchar(6144) not null comment '配置项value',
  constraint uniq_profile_key
    unique (profile_id, `key`)
)
```

* 这样经过测试是没有问题的，后面我的操作就写了bug，我在测试的过程中发现接口比较慢，想优化一下速度，发现接口的操作都是串行的，我创建并发布的配置比较多，所以马上就会想到改为多线程，再联想到插入config_item_release表是以profileId维度，不同profile是相互隔离的，脑补了一下没问题就开干了
* 多线程版本后，运行几次后只有很小的概率会成功，这就踩到坑了


### 定位

首先要看日志，具体日志找不到了，主要是有下面这么一行，deadlock关键字可以定位到问题了，简单思考一下，数据库的并发操作都是不同的数据行，没有并发对统一数据的写操作，下面就开始科学排查了（Google）

***### Cause: com.mysql.jdbc.exceptions.jdbc4.MySQLTransactionRollbackException: Deadlock found when trying to get lock; try restarting transaction***

首先要找到MySQL死锁的日志，都说用这个SQL *SHOW ENGINE INNODB STATUS* 可以看；我怎么搞都不行，最后是用 *select @@log_error* 找到MySQL错误日志的位置，再通过命令行去看的，如下

```
------------------------
LATEST DETECTED DEADLOCK
------------------------
-- 这行可以定位到头发越来越少的原因了😹
2020-11-12 03:04:06 0x70000fccb000
-- 第一个事务
*** (1) TRANSACTION:
-- 事务id=69581 正在执行插入语句
TRANSACTION 69581, ACTIVE 0 sec inserting
-- 使用到了两张表，加锁了两张表
mysql tables in use 2, locked 2
-- 事务处于LOCK WAIT状态，有6种锁结构 其中4个行锁
LOCK WAIT 6 lock struct(s), heap size 1136, 4 row lock(s), undo log entries 1
-- 线程信息
MySQL thread id 627, OS thread handle 123145568219136, query id 21548 localhost 127.0.0.1 root Sending data
-- 事务发生阻塞的SQL语句
INSERT INTO config_item_release
        SELECT * FROM config_item c WHERE c.profile_id=8720
-- 等待获取的锁
*** (1) WAITING FOR THIS LOCK TO BE GRANTED:
-- 等待获取唯一索引insert intention锁 细节1
RECORD LOCKS space id 1112 page no 1955 n bits 376 index uniq_profile_key of table `my_table`.`config_item_release` trx id 69581 lock_mode X insert intention waiting
-- 该记录的信息
Record lock, heap no 1 PHYSICAL RECORD: n_fields 1; compact format; info bits 0
-- supremum 细节2
 0: len 8; hex 73757072656d756d; asc supremum;;

-- 第二个事务
*** (2) TRANSACTION:
TRANSACTION 69580, ACTIVE 0 sec inserting
mysql tables in use 2, locked 2
6 lock struct(s), heap size 1136, 4 row lock(s), undo log entries 1
MySQL thread id 626, OS thread handle 123145567383552, query id 21549 localhost 127.0.0.1 root Sending data
INSERT INTO config_item_release
        SELECT * FROM config_item c WHERE c.profile_id=8721
-- 当前获取到锁的信息
*** (2) HOLDS THE LOCK(S):
-- 当前获取到的时唯一索引的X锁 细节3
RECORD LOCKS space id 1112 page no 1955 n bits 376 index uniq_profile_key of table `my_table`.`config_item_release` trx id 69580 lock_mode X
Record lock, heap no 1 PHYSICAL RECORD: n_fields 1; compact format; info bits 0
 0: len 8; hex 73757072656d756d; asc supremum;;

-- 事务等待获取的锁
*** (2) WAITING FOR THIS LOCK TO BE GRANTED:
-- 等待获取唯一索引insert intention锁 细节4
RECORD LOCKS space id 1112 page no 1955 n bits 376 index uniq_profile_key of table `laf_config`.`config_item_release` trx id 69580 lock_mode X insert intention waiting
Record lock, heap no 1 PHYSICAL RECORD: n_fields 1; compact format; info bits 0
 0: len 8; hex 73757072656d756d; asc supremum;;

-- 回滚了事务2
*** WE ROLL BACK TRANSACTION (2)
```

在这段日志中，忽略了几个细节导致在排查问题的时候走了很多的弯路

* 事务在等待的锁是Insert Intention锁，这个锁是间隙锁的一种，容易被忽略掉，刚开始的我还以为是insert操作在等待X锁导致排查的方向就做了
* supremum 代表无穷大，这里也能够猜想到等待锁的时一个区间是(8720,+∞)的间隙锁，这个细节也被我忽略掉了，注意力完全被 lock model X 吸引走了
* 事务2当前获取到的锁是唯一索引的X锁，与事务1等待的锁是不一样的，还是对Insert Intention锁不了解导致这个细节忽略掉了
* 事务2等待的锁和事务1等待的锁是相同的，应该是互相等待对方释放形成了闭环所以才会发生死锁，死锁的基本概念都忘了，感觉自己像做梦一样🤷‍♀️

### 分析

* 从死锁的定义来看，多个事物要获取的资源形成了闭环，结合日志来看两个事务都在insert操作时阻塞，等待相同位置资源锁，并且被对方限制
* 在从日志来看事务1并没有获取到任何的锁，事务2获得的是唯一索引的记录锁，看不出来有什么资源被互相限制；大胆猜想一下，这里一定存在事务已经获取到的锁但是没有在日志中体现出来
* 从日志中被阻塞到的insert操作和Insert Intention关键字入手查找资料发现了惊人的东西，我的知识体系中存在这巨大漏洞，下面就是被忽略的细节
	* 在insert操作之前会有Insert Intention锁(插入意向锁)是间隙锁的一种，从日志来看加锁的间隙为(max,+∞)
	* Insert Intention锁之间只要插入的数据不是同一个数据是不会冲突的
	* 间隙锁和Insert Intention锁之间也会有互斥的关系，已经存在了G锁(间隙锁)是不能在加I锁(插入意向锁)，相反已经存在I锁是可以再加G锁的
	* 两个G锁直接是相互兼容的
* 在补充了这些知识盲区后，真相浮出水面，两个事务都先加了范围是的G锁，下一步都要执行insert操作，insert之前都要加I锁，I锁都被对方事务事先加号的G锁阻塞，形成了闭环，发生死锁
* 结合业务逻辑来看
	* 第一步删除历史数据清空了config_item_release表的数据
    * 第二步更新配置，在config_item表中update操作
    * 第三步发布配置，这个api的逻辑是先删除config_item_release中的记录，在将config_item表中的数据插入进来
    * 问题就出现在第一步清空了config_item_release表的数据后该表中是没有数据的，第三步先delete操作这时候两个事务会加区间为(max,+∞)的G锁，然后insert操作前会在这个区间加I锁，都被对方的G锁排斥形成死锁，
* 那么如果是这个问题，在config_item_release表中存在数据时，不同事务delete加G锁的区间不同在加I锁就不会被阻塞就可以避免死锁了(delete操作的加锁过程见参考文章)

### 验证

这里通过两个实验来验证上面的分析结果

#### 实验一：config_item_release不存在数据，两个事务先delete后insert会发生死锁

|事务1|事务2|结果|分析|
|---|---|---|---|
|begain||||
||begain||||
|DELETE FROM config_item_release WHERE profile_id=9118||Affected rows: 0, Time: 0.002000s|事务1对(max,+∞)区间加G锁|
||DELETE FROM config_item_release WHERE profile_id=9112|Affected rows: 0, Time: 0.002000s|事务2对(max,+∞)区间加G锁|
|INSERT INTO config_item_release SELECT * FROM config_item c WHERE c.profile_id=9108|||事务1对(max,+∞)加插入意向锁，被事务2阻塞|
||INSERT INTO config_item_release SELECT * FROM config_item c WHERE c.profile_id=9112|1213 - Deadlock found when trying to get lock; try restarting transaction, Time: 0.008000s|事务2对(max,+∞)加插入意向锁，被事务1阻塞，出现死锁|

#### 实验二：config_item_release存在数据，两个事务先delete后insert不会发生死锁

首先执行下面两条语句初始化表中的数据

```
INSERT INTO config_item_release SELECT * FROM config_item c WHERE c.profile_id=9111;
INSERT INTO config_item_release SELECT * FROM config_item c WHERE c.profile_id=9112;
```

|事务1|事务2|结果|分析|
|---|---|---|---|
|begain||||
||begain||||
|DELETE FROM config_item_release WHERE profile_id=9111||Affected rows: 1, Time: 0.000000s|事务1对profile_id=9111记录前的间隙加G锁|
||DELETE FROM config_item_release WHERE profile_id=9112|Affected rows: 3, Time: 0.000000s|事务2对profile_id=9112记录前的间隙加G锁|
|INSERT INTO config_item_release SELECT * FROM config_item c WHERE c.profile_id=9111|||事务1阻塞，因为事务2对profile_id=9112之前的间隙加了G锁，9111这条记录刚好在这个区间，事务1要加I锁时被事务2的G锁阻塞|
||INSERT INTO config_item_release SELECT * FROM config_item c WHERE c.profile_id=9112|Affected rows: 3, Time: 0.000000s|事务2先对9112之前的间隙加I锁这个间隙是当前事务的G锁不冲突没有阻塞|
||commit|OK, Time: 0.001000s|事务2成功提交，事务1结束阻塞状态|
|commit||OK, Time: 0.001000s|事务1成功提交|

综上所述，正式由于我先清除了历史数据，在删除表里不存在的记录时多个事务将相同的区间加了G锁，再加I锁时产生死锁，解决：删除业务逻辑中的清除历史数据的操作，保证表中数据存在。

### 总结

* 补充一下自己的知识盲区，重新梳理数据库的锁，详细见[上一篇文章](http://yywang.top/2020/11/16/%E6%8D%8B%E4%B8%80%E6%8D%8BMySQL%E7%9A%84%E9%94%81/#more)
* 避免删除不存在的记录的操作，这个操作会加G锁，可能多个事务的G锁重叠了导致死锁
* 删除操作最好是先找到记录的id再根据id删除；因为只有在唯一索引的删除操作才会加R锁其他情况都会有G锁

### 参考资料

[MySQL DELETE 删除语句加锁分析](https://www.fordba.com/lock-analyse-of-delete.html)

[从一个死锁看mysql innodb的锁机制](https://www.iteye.com/blog/narcissusoyf-1637309)

[一个死锁问题](http://xiaobaoqiu.github.io/blog/2016/07/22/%5B%3F%5D-ge-si-suo-wen-ti/)

[MySQL加锁分析](http://www.fanyilun.me/2017/04/20/MySQL%E5%8A%A0%E9%94%81%E5%88%86%E6%9E%90/)