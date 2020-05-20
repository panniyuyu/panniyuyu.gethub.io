title: ArrayList
author: YyWang
date: 2019-07-26 19:31:05
tags: Java
catagories: Java
---
### ArrayList
#### toArray(T[] a)

~~~
public <T> T[] toArray(T[] a) {
    if (a.length < size)
        // Make a new array of a's runtime type, but my contents:
        return (T[]) Arrays.copyOf(elementData, size, a.getClass());
    System.arraycopy(elementData, 0, a, 0, size);
    if (a.length > size)
        a[size] = null;
    return a;
}
~~~
使用了Arrays.copyOf方法
