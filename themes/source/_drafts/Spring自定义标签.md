title: Spring自定义标签
author: YyWang
date: 2019-07-16 16:42:12
tags:
---
Spring自定义标签主要分两步
+ 编写xsd文件，xml的约束规则
+ 将xsd文件在xml中引入到名称空间中


#### xsd约束
##### 元素 element
###### 简单元素
+ 类型是一般类型的元素(xsd:string、xsd:decimal、xsd:integer、xsd:boolean、xsd:date、xs:time)

+ eg: 
```
<xsd:element name="yywang" type="xsd:string"></xsd:element>```
对应的xml应该为：
```
<yywang>test</yywang>```

###### 复杂元素
+ 与简单元素相对，类型不是一般的类型，可能是包含其他元素，此时除了指定类型外还需要指定类型的约束
+ eg:
```
<xsd:element name="yywang" type="yywangType">
	<xsd:complexType>
     <xsd:attribute name="id" type="xsd:IDREF" use="required"></xsd:attribute>
     <xsd:attribute name="address" type="xsd:string" default="string"></xsd:attribute>
     <xsd:attribute name="age" type="xsd:integer" use="optional"></xsd:attribute>
   </xsd:complexType>
</xsd:element>```
对应的xml为：
```
<yywang id="yywang1" address="xxxx" age=20></yywang>```






+ xsd文件中的注释
	```
    <xsd:annotation>
    	<xsd:documentation><![CDATA[ 这里是注释的内容 ]]></xsd:documentation>
    </xsd:annotation>```