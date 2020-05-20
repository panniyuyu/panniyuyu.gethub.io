title: StringUtils
author: YyWang
date: 2019-07-26 19:32:04
tags: Java
catagories: Java
---
## StringUtils
+ 工作中很多操作字符串的操作，使用到了工具类这里总结下，org.apache.commons.lang3包下的
 
### split(String str, String separatorChars)-->切分字符串 

~~~
public static String[] split(String str, String separatorChars) {
    return splitWorker(str, separatorChars, -1, false);
}
~~~
参数：

- int max ->the maximum number of elements to include in the array. A zero or negative value implies no limit.
这个参数代表返回的字符串的最大长度，0或者-1代表不限制长度
- boolean preserveAllTokens -> if {@code true}, adjacent separators are treated as empty token separators; if {@code false}, adjacent separators are treated as one separator. 这个参数是连续分隔符规则的标志，如果为true连续的分隔符都会匹配，最终得到的字符串数组会有空的值，jdk中的split就是这个规则；如果为false，连续的分隔符只会匹配一次，最终得到的数组不会有空值。eg("1,2,3,,4,5"切分后，true得到[1,2,3,,4,5]而false得到[1,2,3,4,5])，
- 这也是与jdk中的split方法的区别，如果需要使用与jdk相同的规则，工具类中的splitPreserveAllTokens方法可以实现，该方法会调用splitWorker方法且最后的参数为true

所以split方法默认参数为-1和false表示数组长度不收限制，及使用第二个规则进行切割，确保得到的字符串数组没有空值
原理：
+ 先将字符串与分隔符做匹配
+ 匹配到之后将分隔符之前的子串分割add到一个list集合中
+ 最后使用list.toArray返回最终的数组

#### join  待续
