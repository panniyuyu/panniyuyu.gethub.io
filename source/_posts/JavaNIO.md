title: Java NIO
author: YyWang
tags: Java
categories: Java
date: 2020-10-23 17:19:32
---

开门见山，最近打算看一下netty，做这么长时间微服务netty还没看过是不是太飘了，这篇是netty的背景知识

### NIO

Non-blocking I/O 非阻塞I/O；与传统阻塞I/O相比最大的时阻塞和非阻塞的区别；除此之外NIO操作的是缓冲区，以块的形式处理数据，传统I/O以数据流的形式处理数据；而且NIO支持了Selector；我的简单理解，传统I/O相当于拿一根水管（单向的）插入到水桶里，让水从水桶中流出，从水管中得到水（数据）；NIO则是用水管（双向的水管？栗子可能比较糙但就是这么个意思）将桶中的水流入一个小水池中（缓冲区），从小水池中得到水（数据）；所以基于流的读写只能按顺序来，不能改变读写的位置，且只能是单向的，而对于缓冲区的数据来说就可以随意修改读写的指针了

#### Channel
	
* 用来进行IO操作（文件IO或网络IO），与BIO的Stream类似，不同的时Channel是双向的Stream只能是单向的；Channel读写的对象是Buffer

#### Buffer
	
* 用来存放Channel读写的数据，其实就是内存中的一块区域，保存不同类型的数据(ByteBuffer，CharBuffer等，可以理解为数组，字节数组，字符数组等)；首先通过Channel将数据写入到Buffer中，再对Buffer进行读写，flip()切换到读模式，clear()或compact()切换到写模式
	* 对Buffer每次读写之后Buffer都会记录当前的状态，通过capacity（Buffer的最大值），position（下次读或写的位置，每次读写后更新），limit（Buffer中数据的大小）三个属性；0 <= position <= limit <= capacity
	* 向缓冲区写入数据时，limit = capacity， position = 下一次写入的位置（初始为0）；如果想读出缓冲区的数据，调用filp()方法切换为读，limit = 下一次写入的位置（即读的边界），position = 0（从头开始读）；读完数据想要继续写，调用clear()方法，并不是缓冲区里的数据清空，而是将position重新指向0，limit = capacity 与写的状态一样，新写入的数据会覆盖到缓冲区中；compact()方法，将读模式下position-limit的数据复制到buffer的开头，相当与将已经读过的数据覆盖掉，limit = capacity，position = limit - position

#### Selector
  * NIO非阻塞的特性，可以通过Selector使用一个线程监听多个Channel的IO事件，方法是将所有Channel注册到Selector中(这里Channel必须是非阻塞的)，并注册感兴趣的事件，Selector#select方法找到事件发生的Channel进行下一步工作，select这一步是阻塞的如果事件没有发生将一直阻塞，select的操作系统的实现为IO多路复用技术（select，poll，epoll），Linux下使用epoll

简单罗列一下IO模型，和相关实现

##### 阻塞I/O
线程发起I/O请求会一直阻塞等待I/O条件就绪
##### 非阻塞I/O
线程发起I/O请求后，如果I/O条件不是就绪状态立即返回一个状态不会一直等待，可以先做其他的任务，间隔一段时间查看I/O条件是否就绪，如果就绪进行下一步操作
##### 多路复用I/O
非阻塞I/O线程需要一直去询问I/O事件是否就绪，如果线程很多每个线程都不听的去轮询I/O事件必将造成资源的浪费；多路复用I/O将所有线程的I/O请求注册到一个新的线程中（select），由这一个线程进行轮询去查看I/O条件是否就绪，有就绪状态就通知对应的线程进行处理；相当于是把非阻塞I/O中多线程查看I/O条件的事情委托给了单独的一个线程，提高了系统的吞吐量；

在Linux中该模型的实现有select，poll和epoll的系统调用，服务端接受连接，select和poll都会将连接感兴趣的I/O事件保存到一个集合中（fd集合，在Linux中I/O是文件），每次Selector#select传递给内核，内核去寻找集合中满足条件的I/O，返回满足条件的数量，用户线程得到满足I/O条件的数量，需要再次遍历集合找到满足I/O条件的连接进行下一步操作，时间复杂度为O(2n)；epoll使用事件驱动模式，首先将连接感兴趣的I/O注册到内核，并且注册了一个回调函数，当满足I/O条件会发生回调将该I/O对应的fd移动到内核中的就绪队列，每次select只需从就绪队列中读取具备I/O条件的数量即可，再进行下一步的操作，当有m（m<=n）个连接具备条件，时间复杂度为O(m)

##### 信号驱动I/O
这个感觉和多路复用I/O差不多，这里将多线程的I/O操作注册为一个信号，信号中有回调函数，当信号发生call回调函数通知用户线程，先简单这么理解
##### 异步I/O
线程发出I/O请求后不需要做任何操作，I/O操作完全由操作系统内核完成，之后会通知线程I/O已经完成

具体例子可以参考[这里](https://segmentfault.com/a/1190000006824091)
