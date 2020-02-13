title: SQL级联查询一些总结
author: YyWang
date: 2019-11-16 14:34:28
tags: SQL
catagories: SQL
---
子查询导致索引失效

连接查询（连接条件为索引）的效率更高

##### 背景：
微服务相关管理端的系统，用户会在自己对应服务的地方查询所需的server，新增需求为要查看自己的服务所在的app

##### 数据结构：
server在单独的一张表，可以根据服务名称（interface_name）来查询；AppName在另外的一张表中；两张表没有联系需要通过一个中间表来连接；interface_name有索引，三个表之间的链接字段都有索引

##### 分析：
需要联合3张表来查询所需要的数据，每张表的数据量都比较大，而且这个SQL是系统使用最频繁的部分查询的频率还特别高，所以要尽可能快的出结果

##### 我的心路历程：
先通过interface_name条件筛选出一部分数据再链接另外两张表查询，都有索引一定是最优的，SQL如下

```
SELECT
	app_name 
FROM
	saf_app 
WHERE
	app_id IN 
	( 
		SELECT DISTINCT app_id FROM saf_ins_hb WHERE ins_key IN 
		(SELECT ins_key FROM saf_server WHERE interface_name = 'xxx') 
	)
 ORDER BY app._name
```

查询时间竟然需要6s多，这绝对是不能忍的，接着我又试了一下级联查询，SQL如下

```
SELECT DISTINCT app.app_name 
	FROM saf_server s 
LEFT JOIN saf_ins_hb hb ON s.ins_key = hb.ins_key
LEFT JOIN saf_app app ON hb.app_id = app.app_id
	WHERE s.interface_name = 'xxx' 
	ORDER BY app.app_name
```

这次的结果只需0.05s,相差100倍还多

explain看下呢

IN子查询如下

![upload successful](/images/pasted-19.png)

可以看到id为2和3的查询都用到了索引并且只需扫描的很少的行数，到了最外层的查询就变成了全表扫描了，索引就失效了

级联查询如下

![upload successful](/images/pasted-18.png)

级联查询全部使用到了索引，而且扫描的行数比子查询的要少很多，扫描的最终行数是乘积的关系，级联查询有两个子查询的rows为1所以要比IN子查询要小很多

所以说IN子查询会导致部分索引失效，我有了新的想法，既然连接查询会很快那么我先通过条件筛选出数据再做级联查询不是更快了，开整~ SQL如下

```
SELECT DISTINCT app.app_name 
    FROM (SELECT ins_key FROM saf_server WHERE interface_name = 'xxx') s 
LEFT JOIN saf_ins_hb hb ON s.ins_key = hb.ins_key
LEFT JOIN saf_app app ON hb.app_id = app.app_id
    ORDER BY app.app_name
```
查询0.02s左右，我非常满意，explain一下呢

![upload successful](/images/pasted-17.png)

相较于级联查询还多了7000多次的遍历？？？子查询害人啊，查询结果0.02s左右应该是有缓存

看了一篇文章说在on后面加限制条件会比where中加限制条件用时要少，on后面加条件在两张表做连接的同时过滤掉一些数据后再和第三张表做连接，where是将连接了所有表之后的结果进行筛选，听着很有道理，那我试一下呢，SQL如下

```
SELECT DISTINCT app.app_name 
    FROM saf_server s 
LEFT JOIN saf_ins_hb hb ON s.ins_key = hb.ins_key and s.interface_name = 'xxx'
LEFT JOIN saf_app app ON hb.app_id = app.app_id
    ORDER BY app.app_name
```

explain看下

![upload successful](/images/pasted-16.png)

结果非常意外，不仅时间没有省下来，索引也没有使用，进行全表扫描，还好我验证了一下，原因的话还不知道，对mysql底层不是很熟悉，先暂时把遇到的问题记录下来吧 ^_^

**结论：子查询会导致索引失效，尽量不使用子查询，用级联查询代替，并将级联查询的条件设置建立索引**

##### 级联查询的原理
mysql会首先找到一张表作为驱动表，就是首先要进行查询的表，以驱动表为基础匹配剩下的表，inner join的情况mysql会选择数据量小的表作为驱动表，left/right join分别以左/右表作为驱动表；接着会根据on的条件过滤结果，最终将连接的表都筛选完成后如果有where语句指定条件将进行最后的筛选得到结果

连接的算法也很简单，连接条件没有索引则进行全表扫描然后进行匹配，如果还有表连接则将匹配的结果继续与剩余的表进行扫描匹配，这种方法简单粗暴，叫做嵌套循环连接（Nested-Loop Join）；Mysql对这种方式有了优化，增加了join buffer，是将驱动表关联条件的相关列缓存起来，并将多次匹配合并，减少的匹配的次数，以此方式来加速查询结果，叫做BLJ算法（Block Nested-Loop Join）；有索引则会先匹配索引，匹配后的结果再插到对应的数据返回

综上，级联查询的查询条件最好是加索引，虽然mysql对没有索引的链接做了优化，那也是没有索引的方式快的，而且最好链接的条件是主键索引，这是由于非主键索引指向的时主键索引，要得到数据还要跑一次主键索引；还有我想到了阿里巴巴java开发规范中写道多余三张表不能使用join，用多次简单查询代替这个也要注意一下

参考： [MySQL查询优化——连接以及连接原理](https://www.jianshu.com/p/048d93d3ee54)
