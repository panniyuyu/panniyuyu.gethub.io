---
title: iptables是个啥
author: YyWang
date: 2021-07-13 21:16:15
tags: Linux
categories: Linux
---
## 前言
iptables 是 Linux 中经常使用的防火墙，还记得之前部署 Tomcat 服务到一个 web 服务器需要配置新的 iptables 规则，开放8080端口，否则无法访问自
己的服务，当时满脑子只想完成任务，网上 copy 命令改改改直接敲，甚至直接粗暴的关闭防火墙 🤐 现在 k8s 中的服务发现以及 service mesh 中的流量劫持
都使用到了 iptables。so 今天我来还债了

## 概述
iptables其实不是防火墙，真正的防火墙是 netfilter 字面意思就是网络过滤器，可以过滤进出 Linux 网络协议栈的数据包，通过指定各种自定义的规则对进
出的数据包进行拦截修改等操作，netfilter 在内核空间处于内核态，而 iptables 是对 netfilter 的配置工具，通过 iptables 可以配置 netfilter 的
过滤规则，iptables 在用户空间处于用户态。这么看 iptables 可以理解成"控制面"，netfilter 可以理解成"数据面"

## 原理
netfilter 在数据包进出 Linux 网络协议栈的不同节点上设有 hooks （可以理解为回调函数），当满足了匹配条件就会出发回调进行后面的操作，hooks 主要
在 PRE_ROUTING、LOCAL_IN、FORWARD、LOCAL_OUT 和 POST_ROUTING 5个位置上，覆盖了数据包进出 Linux 协议栈的整个生命周期，来整一张图看下这
5个位置（图中橙色的圆型就是）

![iptables1](/images/iptables1.png)

* PRE_ROUTING 在数据包进入被路由前进入这个节点，这个节点之后会进行路由
* LOCAL_IN 在数据包被路由之后，判定目的地址是本机，会进入这个节点，这个节点之后会将数据包传递给应用程序
* FORWARD 在数据包被路由之后，判定目的地址不是本机，会进入这个节点，这个节点之后会重新路由，将数据包传递出去
* LOCAL_OUT 应用程序发出数据包，还没有路由前，这个节点之后会进行路由
* POST_ROUTING 在应用程序，或者 FORWARD 发出的数据包路由之后进入这个节点，这个节点后会将数据包发送出去

## iptables 表和链
iptables 有"四表五链"来管理数据包的规则和动作

* 五链，对应上图中五个橙色的 hooks，
  * PREROUTING 对应 PRE_ROUTING hooks
  * INPUT 对应 LOCAL_IN hooks
  * FORWARD 对应 FORWARD hooks
  * OUTPUT 对应 LOCAL_OUT hooks
  * POSTROUTING 对应 POST_ROUTING hooks
* 四表，将链上的动作按照不同的类别分成了4张表，优先级依次是 Raw->Mangle->NAT->Filter
  * Raw，决定数据包是否被状态跟踪机制处理
  * Mangle，用来修改数据包的 TOS、TTL 配置
  * NAT，用来修改数据包的 Ip 地址和端口等信息，做网络地址转换（SNAT、DNAT）
  * Filter，用来过滤数据包，决定数据包的去留，接受或者拒绝
  
### 表和链的关系
表和链属于多对多的关系，"表中有链，链中有表"

| | PREROUTING | INPUT | FORWARD | OUTPUT | POSTROUTING |
|---|---|---|---|---|---|
|Raw| ✅ | | | ✅ | ✅ |
|Mangle| ✅ | ✅ | ✅ | ✅ | ✅ |
|Nat| ✅ | | | ✅ | ✅ |
|Filter| | ✅ | ✅ | ✅ | |

按链的维度来看，不同的链中包含的表不同，说明每个链的功能不一样，比如 PREROUTING 链只包含 Raw、Mangle、Nat 三个表也就是说只能配置这三个表的动作；
按表的维度来看，不同的表中的链不是相同的，也就是说表所配置的动作只能在特定的链上，比如说要做 ip 地址转（即 Nat 表）只可以在 PREROUTING、OUTPUT
、POSTROUTING 三 个链上进行；那么数据包在进入网络协议栈的过程就变成了这样（其中 hooks 换成了链）

![iptables2](/images/iptables2.png)

## 配置

```
iptables [-t 表名] COMMAND [要操作的链名] [匹配规则] -j [目标动作]
```

* COMMAND
  * -A ：append 新增加一条规则，该规则增加在原本规则的最后面。不显式指定表默认为filter表
  * -D ：delete 删除一条规则
  * -I ：insert 插入一条规则，如果没有指定顺序默认插入成第一条规则
  * -R ：replace 替换一条规则
  * -L ：list 查看规则
  
* 匹配规则
  * -p ：指定匹配的协议 tcp、upd、icmp、all
  * -s ：指定匹配来源 IP 或者网段
  * -d ：指定匹配目的 IP 或者网段
  * --sport ：指定匹配源端口 
  * --dport ：指定匹配目的端口

* 目标动作 ACCEPT、DROP、REJECT、LOG

[这篇文章](https://www.huaweicloud.com/articles/3abf0cf9743f2f582f45e320452596f6.html)最后有些例子可以参考一下

## 参考

* https://xie.infoq.cn/article/b0cfe588251d024d9114c84f3
* https://cloud.tencent.com/developer/article/1619659
* https://www.huaweicloud.com/articles/3abf0cf9743f2f582f45e320452596f6.html