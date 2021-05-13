---
title: 没有实践就不算入门 Istio
author: YyWang
date: 2021-05-08 15:28:20
tags: Istio
catagories: Istio
---

### 简述
Istio 是如何使用网关进行流量控制的呢？经过两天的实验和研究，有了一个简单的认识，记录一下子

Istio 作为服务网格的控制面通过一些自定义的 CR，通过对这些 CR 的配置，并对这些 CR 和 k8s 中部分资源 listAndWatch 生成配置并下发（xds协议）
到数据面，数据面接收到这些配置实时调整对流量的处理逻辑，这是大致的流程。在原生的 k8s 中，Service 可以通过筛选 label 将应用的多个实例暴露出去提
供服务，Service 还可以服务发现和负载均衡，在此基础上 Istio 定义了一些 CR 来扩展 Service 的功能，本文就 Istio 针对 Http 协议的流量 控制进行
实践，对 Istio 有一个简单的认识。

### Demo 结构

![istio-1](/images/istio-1.png)

从右往左看
* 通常使用 Deployment 来部署应用的多个实例即业务 Pod，对应图中 business Pod
* 创建 Service 将业务 Pod 暴露提供服务，同时可以服务发现和负载均衡

到这只是使用了 k8s 中的 CR，用户可以通过访问 Service 的 ClusterIp 和端口来访问服务，但是没有更细致的流量控制的功能，下面就开始使用 Istio

* 需要创建 VirtualService 和 DestinationRule 来配置流量控制规则
* VirtualService 可以配置不同维度的路由规则将流量传递给指定的 Service
* DestinationRule 可以配置路由规则的不同子集(理解为 k8s Service 中 Endpoint 分组)，以及子集的复制均衡策略，还能配置异常检测
* 还可以创建网关来进行流量控制，Istio 默认使用 Envoy 做网关，同样使用 Deployment 部署多个实例，（图中 gateway Pod）创建 Service（图中 
  gateway service）提供服务，Gateway 是 Istio 的 CR 通过筛选 label 关联到创建好的网关，Gateway 规定能够通过网关的流量，并绑定 VisualService
  和 DestinationRule 的规则
  
Istio 通过 ListAndWatch 这些 CR 感知到它们的变化通知给数据面（sidecar 或者 Gateway）

### 实践

#### 准备工作

+ 首先用 Deployment 部署一个 HttpServer 的 Demo，有两个实例 

```
NAME                        READY   STATUS    RESTARTS   AGE   IP            NODE                  NOMINATED NODE   READINESS GATES
http-sample.default-24tqt   1/1     Running   2          8d    10.0.76.95    op-arsenaldevk8s-03   <none>           1/1
http-sample.default-crkvp   1/1     Running   4          8d    10.0.76.102   op-arsenaldevk8s-07   <none>           1/1
```

* 给 Demo 创建 Service 暴露服务，

```

NAME                   TYPE        CLUSTER-IP    EXTERNAL-IP   PORT(S)             AGE
http-sample--default   ClusterIP   10.0.75.60    <none>        8386/TCP            7d19h

```

* 创建 Gateway CR 用来接收所有 host 的请求

```

apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: httpsample-gateway
spec:
  selector:
    istio: ingressgateway # use Istio default gateway implementation 使用 envoy 
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "*" // 被网关管理 host，这里配置了所有；

```

* Istio 默认在 istio-system 下创建了网关的 Deployment 和 Service，同样 Service 通过筛选 label 关联 Deployment 的实例 

```

kubectl get deployment -n istio-system
NAME                   READY   UP-TO-DATE   AVAILABLE   AGE
istio-ingressgateway   2/2     2            2           28d

ubectl get svc -n istio-system
NAME                   TYPE           CLUSTER-IP    EXTERNAL-IP   PORT(S)                                                                      AGE
istio-ingressgateway   LoadBalancer   10.0.75.173   <pending>     15021:31214/TCP,80:30611/TCP,443:32529/TCP,15012:32583/TCP,15443:31725/TCP   28d

```

* 创建 VirtualService 绑定网关

```

apiVersion: networking.istio.io/v1beta1
kind: VirtualService
spec:
  gateways:
  - httpsample-gateway // 绑定网关，被绑定的网关使用该 VirtualService 配置的规则进行流量控制
  hosts:
  - '*' // 针对某个 host 的应用路由规则，必须包含在被绑定的网关 hosts 范围中，配置成一样的就可以

```

* 创建 DestinationRule 划分两个子集不同版本的子集，

```

apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
spec:
  host: http-sample--default
  subsets: // 通过筛选 label 划分不同的子集，label 是在业务 Pod 的 Service 中 Label Selector 基础上增加版本的标签
  - labels:
      app: http-sample // Service 中筛选标签的条件
      version: v1 // 新增的筛选标签的条件
    name: v1
  - labels:
      app: http-sample
      version: v2
    name: v2

```

最后，给 Demo 的两个实例分别打上 version 标签，本文规定10.0.76.95的 IP 是v1，10.0.76.102的 IP 是v2，准备工作完成

#### 路由配置

```

apiVersion: networking.istio.io/v1beta1
kind: VirtualService
spec:
  gateways:
  - httpsample-gateway
  hosts:
  - '*'
  http:
  - route:
    - destination:
        host: http-sample--default // 路由的目标 Service，流量会被路由到的 Service
        port:
          number: 8386 // 路由的目标 Service 端口
        subset: v2 // 路由的目标子集，DestinationRule 中定义的子集
        weight: 100 // 流量分配权重

```

验证

```

// 访问网关的 Service
curl http://10.0.75.173
// Demo 程序返回时间，host，IP 信息可以看到流量被路由到了 v2 子集上
hello!Sat, 08 May 2021 05:58:10 UTC,host:http-sample.default-crkvp,ip:10.0.76.102

```

#### 匹配规则

```

apiVersion: networking.istio.io/v1beta1
kind: VirtualService
spec:
  gateways:
  - httpsample-gateway
  hosts:
  - '*'
  http:
  - match:
    - headers: // 匹配请求头 还支持前缀匹配(prefix)和正则匹配(regex)
        userpin:
          exact: jason
    - uri: // 匹配 uri 还支持精确匹配(exact)和正则匹配(regex)
        prefix: /tov1
    route: // match 的请求路由规则
    - destination:
        host: http-sample--default
        port:
          number: 8386
        subset: v1
  - match:
    - headers: // 匹配请求头 还支持前缀匹配(prefix)和正则匹配(regex)
        userpin:
          exact: yywang // 这里如果是 jason 会优先匹配到上条规则
      uri:
        prefix: /tov2
    route:
    - destination:
        host: http-sample--default
        port:
          number: 8386
        subset: v2
  - route: // 默认路由规则，即上面没有 match 到会直接路由到 http-sample--default 的 Service (Demo 暴露的 Service)上
    - destination:
        host: http-sample--default
        port:
          number: 8386

```

match 中的匹配规则，在不同的数组下是或的关系如v1的配置，相同数组下是且的黄兴如v2的配置

验证

```

// 路径匹配
curl http://10.0.75.173/tov1
hello!Sat, 08 May 2021 06:15:25 UTC,host:http-sample.default-24tqt,ip:10.0.76.95
// header 匹配
curl -H "userpin:jason" http://10.0.75.173/
hello!Sat, 08 May 2021 06:15:05 UTC,host:http-sample.default-24tqt,ip:10.0.76.95
// 优先匹配v1
curl -H 'userpin:jason'  http://10.0.75.173/tov2
hello!Sat, 08 May 2021 06:19:48 UTC,host:http-sample.default-24tqt,ip:10.0.76.95
// v2是且的关系，最后走了默认路由两个实例随机访问
curl  http://10.0.75.173/tov2
hello!Sat, 08 May 2021 06:19:08 UTC,host:http-sample.default-24tqt,ip:10.0.76.95
curl  http://10.0.75.173/tov2
hello!Sat, 08 May 2021 06:19:09 UTC,host:http-sample.default-24tqt,ip:10.0.76.95
curl  http://10.0.75.173/tov2
hello!Sat, 08 May 2021 06:19:09 UTC,host:http-sample.default-crkvp,ip:10.0.76.102
// 匹配v2
curl -H 'userpin:yywang'  http://10.0.75.173/tov2
hello!Sat, 08 May 2021 06:26:17 UTC,host:http-sample.default-crkvp,ip:10.0.76.102

```

#### 流量镜像

```

apiVersion: networking.istio.io/v1beta1
kind: VirtualService
spec:
  gateways:
  - httpsample-gateway
  hosts:
  - '*'
  http:
  - match:
    - uri:
        prefix: /tov1
    mirror:
      host: http-sample--default // 流量镜像的目标 Service
      subset: v2 // 流量镜像的目标 子集
    mirror_percent: 100 // 流量镜像的比例
    route:
    - destination:
        host: http-sample--default
        port:
          number: 8386
        subset: v1
  - match:
      uri:
        prefix: /tov2
    route:
    - destination:
        host: http-sample--default
        port:
          number: 8386
        subset: v2
  - route: 
    - destination:
        host: http-sample--default
        port:
          number: 8386

```

验证，curl http://10.0.75.173/tov1 在v2的 Pod 上查看日志

#### CORS 策略

```

apiVersion: networking.istio.io/v1beta1
kind: VirtualService
spec:
  gateways:
  - httpsample-gateway
  hosts:
  - '*'
  http:
  - route:
    - destination:
        host: http-sample--default
        port:
          number: 8386
        subset: v2
        weight: 100
    corsPolicy:
      allowOrigin:
      - new.com // 允许浏览器跨域访问的地址
      allowMethods:
      - GET // 允许浏览器跨域访问的请求方法
      maxAge: "2m" // 跨域请求缓存的时间

```

目前没有遇到这个策略的场景，就没有做验证，据了解 CORS 会给原请求添加头信息，可以查看请求头验证，[参考](https://zhuanlan.zhihu.com/p/264800677)

#### 重定向

```

apiVersion: networking.istio.io/v1beta1
kind: VirtualService
spec:
  gateways:
  - httpsample-gateway
  hosts:
  - '*'
  http:
  - match:
    - uri:
        prefix: /tov1
    redirect:
      uri: /tov2 // 重定向的路径
      authority: 172.16.26.126:8386 // 重定向的主机，不配置就是当前主机，这个是我本地的地址和端口
  - match:
      uri:
        prefix: /tov2
    route:
    - destination:
        host: http-sample--default
        port:
          number: 8386
        subset: v2

```

验证：curl http://10.0.75.173/tov1 查看本地日志发现被路由到了本地

#### 重写

类似于请求转发，浏览器 URL 不会变，由服务器转发新地址

```

apiVersion: networking.istio.io/v1beta1
kind: VirtualService
spec:
  gateways:
  - httpsample-gateway
  hosts:
  - '*'
  http:
  - match:
    - uri:
        prefix: /tov1
    rewrite:
      uri: /print // 重写的路径
      authority: 172.16.26.126:8386 // 重写的主机
    route:
    - destination:
        host: http-sample--default
        port:
          number: 8386
        subset: v1
  - match:
      uri:
        prefix: /tov2
    route:
    - destination:
        host: http-sample--default
        port:
          number: 8386
        subset: v2

```

验证方式同重定向一样，有一点区别的是重写下面还可以配置路由，如果没有配置重写的主机名默认会路由到下面的子集，上面的例子如果没有配置重写的主机会路由
到v1的 /print 的 path 上

#### 重试

```

apiVersion: networking.istio.io/v1beta1
kind: VirtualService
spec:
  gateways:
  - httpsample-gateway
  hosts:
  - '*'
  http:
  - route: 
    - destination:
        host: http-sample--default
        port:
          number: 8386
    retries:
      attempts: 3 // 重试次数
      perTryTimeout: 2s // 重试超时等待时间
      retryOn: 5xx,connect-failure // 重试条件 5xx 状态码或者连接失败

```

验证，Demo 中有一个返回500错误的方法，curl http://10.0.75.173/error500 打开两个 Pod 的实例观察请求的日志，加上重试一共请求4次

#### 故障注入

##### 延迟故障

```

apiVersion: networking.istio.io/v1beta1
kind: VirtualService
spec:
  gateways:
  - httpsample-gateway
  hosts:
  - '*'
  http:
  - fault:
      delay: // 注入延迟故障
        percentage:
          value: 10 // 注入百分比
        fixedDelay: 5s // 延迟时间
  - route: 
    - destination:
        host: http-sample--default
        port:
          number: 8386

```

##### 错误故障

```

apiVersion: networking.istio.io/v1beta1
kind: VirtualService
spec:
  gateways:
  - httpsample-gateway
  hosts:
  - '*'
  http:
  - fault:
      abort: // 错误故障
        percentage:
          value: 10 // 注入百分比 
        httpStatus: 500 // 响应状态码
  - route: 
    - destination:
        host: http-sample--default
        port:
          number: 8386

```

curl http://10.0.75.173 即可验证

#### 负载均衡

Istio 除了 Service 本身带有的负载均衡，在 DestinationRule 中可以配置子集的负载均衡，支持更多算法

```

apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
spec:
  host: http-sample--default
  subsets:
  - labels:
      version: v1
      app: http-sample
    name: v1
    trafficPolicy:
      lodaBalancer: // 负载均衡配置
        simple: ROUND_ROBIN // 轮询负载均衡算法，还支持随机算法(RANDOM)，最少连接(LEAST_CONN)，直接转发(PASSTHROUTE)

```

#### 异常检测 - 熔断限流

```

apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
spec:
  host: http-sample--default
  subsets:
  - labels:
      version: v1
      app: http-sample
    name: v1
  - labels:
      version: v2
      app: http-sample
    name: v2
  trafficPolicy:
    connectionPool:
      http:
        http1MaxPendingRequests: 1 // 最大请求等待数
        maxRequestsPerConnection: 1 // 每个连接最大请求数
      tcp:
        macConnections: 1 // 最大连接数
    outlierDetection:
      baseEjectionTime: 100s // 基础熔断时间，实际时间是 = 基础熔断时间 x 熔断次数
      consecutiveErrors: 1 // 触发熔断的连续错误次数
      maxEjectionPercent: 100 // 熔断实例的比例，100%即为所有实例都可以同时熔断

```

验证，这里通过 fortio 验证了限流，再高于5个连接并发的情况下会有部分请求失败被限流，熔断还还不知道怎么验证，感觉应该没问题后面验证了再补充上

```

fortio load -c 5 -qps 0 -n 100 -loglevel Warning http://10.0.75.173
17:45:28 I logger.go:127> Log level is now 3 Warning (was 2 Info)
Fortio 1.14.1 running at 0 queries per second, 8->8 procs, for 100 calls: http://10.0.75.173
Starting at max qps with 5 thread(s) [gomax 8] for exactly 100 calls (20 per thread + 0)
17:45:28 W http_client.go:781> Parsed non ok code 503 (HTTP/1.1 503)
17:45:28 W http_client.go:781> Parsed non ok code 503 (HTTP/1.1 503)
17:45:28 W http_client.go:781> Parsed non ok code 503 (HTTP/1.1 503)
17:45:28 W http_client.go:781> Parsed non ok code 503 (HTTP/1.1 503)
17:45:28 W http_client.go:781> Parsed non ok code 503 (HTTP/1.1 503)
17:45:28 W http_client.go:781> Parsed non ok code 503 (HTTP/1.1 503)
17:45:28 W http_client.go:781> Parsed non ok code 503 (HTTP/1.1 503)
17:45:28 W http_client.go:781> Parsed non ok code 503 (HTTP/1.1 503)
17:45:28 W http_client.go:781> Parsed non ok code 503 (HTTP/1.1 503)
17:45:28 W http_client.go:781> Parsed non ok code 503 (HTTP/1.1 503)
17:45:28 W http_client.go:781> Parsed non ok code 503 (HTTP/1.1 503)
17:45:29 W http_client.go:781> Parsed non ok code 503 (HTTP/1.1 503)
17:45:29 W http_client.go:781> Parsed non ok code 503 (HTTP/1.1 503)
17:45:29 W http_client.go:781> Parsed non ok code 503 (HTTP/1.1 503)
17:45:29 W http_client.go:781> Parsed non ok code 503 (HTTP/1.1 503)
17:45:29 W http_client.go:781> Parsed non ok code 503 (HTTP/1.1 503)
17:45:29 W http_client.go:781> Parsed non ok code 503 (HTTP/1.1 503)
17:45:29 W http_client.go:781> Parsed non ok code 503 (HTTP/1.1 503)
Ended after 181.75592ms : 100 calls. qps=550.19
Aggregated Function Time : count 100 avg 0.0084987707 +/- 0.003829 min 0.003318402 max 0.01871654 sum 0.849877069
# range, mid point, percentile, count
>= 0.0033184 <= 0.004 , 0.0036592 , 8.00, 8
> 0.004 <= 0.005 , 0.0045 , 15.00, 7
> 0.005 <= 0.006 , 0.0055 , 26.00, 11
> 0.006 <= 0.007 , 0.0065 , 44.00, 18
> 0.007 <= 0.008 , 0.0075 , 58.00, 14
> 0.008 <= 0.009 , 0.0085 , 64.00, 6
> 0.009 <= 0.01 , 0.0095 , 73.00, 9
> 0.01 <= 0.011 , 0.0105 , 75.00, 2
> 0.011 <= 0.012 , 0.0115 , 80.00, 5
> 0.012 <= 0.014 , 0.013 , 88.00, 8
> 0.014 <= 0.016 , 0.015 , 94.00, 6
> 0.016 <= 0.018 , 0.017 , 98.00, 4
> 0.018 <= 0.0187165 , 0.0183583 , 100.00, 2
# target 50% 0.00742857
# target 75% 0.011
# target 90% 0.0146667
# target 99% 0.0183583
# target 99.9% 0.0186807
Sockets used: 23 (for perfect keepalive, would be 5)
Jitter: false
Code 200 : 82 (82.0 %)
Code 503 : 18 (18.0 %)
Response Header Sizes : count 100 avg 141.04 +/- 66.08 min 0 max 172 sum 14104
Response Body/Total Sizes : count 100 avg 252.32 +/- 2.533 min 247 max 254 sum 25232
All done 100 calls (plus 0 warmup) 8.499 ms avg, 550.2 qps

```
