title: Arrays
author: YyWang
tags: Java
catagories: Java
date: 2019-07-26 19:31:27
---
### Arrays
#### copyOf
~~~
public static <T,U> T[] copyOf(U[] original, int newLength, Class<? extends T[]> newType) {
    @SuppressWarnings("unchecked")
    T[] copy = ((Object)newType == (Object)Object[].class)
        ? (T[]) new Object[newLength]
        : (T[]) Array.newInstance(newType.getComponentType(), newLength);
    System.arraycopy(original, 0, copy, 0,
                     Math.min(original.length, newLength));
    return copy;
}
~~~

先看要被拷贝到的数组长度是不是够用，够用的话直接调用System.arraycopy方法；不够用创建一个新的与源数组同样长度的数组进行拷贝
**如果数组中是引用类型，Arrays.copy拷贝的是引用，不会新创建对象，如果要对拷贝的数组做修改操作源数组同样会受到影响，而字符串数组由于字符串常量池的存在，当修改字符串的时候会新创建一个字符串并将新的引用付给数组，所以源数组对应的字符串并不会发生变化**

##### System.arraycopy
~~~
public static native void arraycopy(Object src,  int  srcPos,
                                    Object dest, int destPos,
                                    int length);
~~~
这是一个本地方法，就看一下参数吧

+ src----the source array. 
+ srcPos----starting position in the source array.
+ dest----the destination array.
+ destPos----starting position in the destination data.
+ length----the number of array elements to be copied.


#### asList
将字符串转成ArrayList集合

~~~
public static <T> List<T> asList(T... a) {
    return new ArrayList<>(a);
}
~~~

这里的ArrayList是Arrays中的一个内部类，继承了AbstractList方法，内部值实现了部分方法，简单点说这个集合是只读的，不能进行修改和删除操作，因为没有重写相关的方法。

#### copyOfRange
按照范围拷贝数组 [from,to) 左开右闭
```
public static <T> T[] copyOfRange(T[] original, int from, int to) {
    return copyOfRange(original, from, to, (Class<? extends T[]>) original.getClass());
}
```

#### sort 

集合工具类 Collections.sort 其实就是调用 Arrays.sort 方法对集合进行排序的，该方法先调用 toArray 方法将集合转成object数组，然后再调用 Arrays.sort 方法对数组进行排序，最后再将排序号的数组通过迭代器set到新的集合中去。

```
public static void sort(Object[] a) {
    if (LegacyMergeSort.userRequested)
        legacyMergeSort(a);
    else
        ComparableTimSort.sort(a, 0, a.length, null, 0, 0);
}
```
可以看到sort方法是通过userRequested的标志来选中排序的方式，从jdk7以后默认为false，使用TimSort的方式排序，（通过System.setProperty("java.util.Arrays.useLegacyMergeSort", "true")修改）

- userRequested为true使用LegacyMergeSort的方式进行排序，当数组长度小于7时使用插入排序，当数组长度大于7时使用归并排序，归并到长度小于7的长度再次使用插入排序
- userRequested为false采用TimSort的方式排序

##### TimSort
+ 1.数组长度小于32时，首先在数组中从开头开始寻找升序的子数组，没有的话找降序的子数组再反转，然后将数组中的剩余元素使用二分查找的方式插入到子数组中
+ 2.数组长度大于32时，将数组切分若干个长度在[16,32)的区块（jdk里叫run，我理解为区块）
+ 3.每个区块再使用第一步的方式进行排序排序后将每个区块进行合并，合并的过程有两点优化
 + a.合并区块的过程中通过限制条件来完成将连续的三个区块中较小的两个优先合并降低复杂度
 + b.两个区块合并时，先将区块1的头元素和尾元素插入到区块2中，相当于缩小了插入区块2的范围降低复杂度

```
static void sort(Object[] a, int lo, int hi, Object[] work, int workBase, int workLen) {
    assert a != null && lo >= 0 && lo <= hi && hi <= a.length;

    int nRemaining  = hi - lo;
    if (nRemaining < 2)
        return;  // Arrays of size 0 and 1 are always sorted

    // If array is small, do a "mini-TimSort" with no merges
    if (nRemaining < MIN_MERGE) {
        int initRunLen = countRunAndMakeAscending(a, lo, hi);
        binarySort(a, lo, hi, lo + initRunLen);
        return;
    }

    /**
     * March over the array once, left to right, finding natural runs,
     * extending short natural runs to minRun elements, and merging runs
     * to maintain stack invariant.
     */
    ComparableTimSort ts = new ComparableTimSort(a, work, workBase, workLen);
    int minRun = minRunLength(nRemaining);
    do {
        // Identify next run
        int runLen = countRunAndMakeAscending(a, lo, hi);

        // If run is short, extend to min(minRun, nRemaining)
        if (runLen < minRun) {
            int force = nRemaining <= minRun ? nRemaining : minRun;
            binarySort(a, lo, lo + force, lo + runLen);
            runLen = force;
        }

        // Push run onto pending-run stack, and maybe merge
        ts.pushRun(lo, runLen);
        ts.mergeCollapse();

        // Advance to find next run
        lo += runLen;
        nRemaining -= runLen;
    } while (nRemaining != 0);

    // Merge all remaining runs to complete sort
    assert lo == hi;
    ts.mergeForceCollapse();
    assert ts.stackSize == 1;
}
```
