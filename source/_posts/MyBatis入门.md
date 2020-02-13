title: MyBatis入门
author: YyWang
tags: MyBatis
catagories: MyBatis
date: 2019-07-12 13:16:20
---
#### MyBatis环境

##### 首先准备数据库表
+ 对应的实体类为
- ```public class User {
    private int id;
    private String name;
    private String sex;
    private int age;
    private String desc;
   }```

##### 数据库配置文件 *SqlMapConfig.xml*
+ 配置数据库环境相关
- ```
<environments default="development">
        <environment id="development">
            <transactionManager type="JDBC"/>
            <dataSource type="POOLED">
                <property name="driver" value="com.mysql.jdbc.Driver"/>
                <property name="url" value="jdbc:mysql://localhost:3306/test?characterEncoding=utf-8"/>
                <property name="username" value="root"/>
                <property name="password" value="root"/>
            </dataSource>
        </environment>
 </environments>```
  
##### sql映射文件 *user.xml*
+ ```
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE mapper
        PUBLIC "-//mybatis.org//DTD Mapper 3.0//EN"
        "http://mybatis.org/dtd/mybatis-3-mapper.dtd">
<mapper namespace="test">
    <select id="findUserById" parameterType="int" resultType="com.example.mybatisdemo.bean.User">
        SELECT * FROM user WHERE id =#{VALUE}
    </select>
</mapper>
```

##### 将sql映射添加到SqlMapConfig.xml中
+ 最终的配置文件为
- ```
<?xml version="1.0" encoding="UTF-8" ?>
<!DOCTYPE configuration
        PUBLIC "-//mybatis.org//DTD Config 3.0//EN"
        "http://mybatis.org/dtd/mybatis-3-config.dtd">
<configuration>
    <environments default="development">
        <environment id="development">
            <transactionManager type="JDBC"/>
            <dataSource type="POOLED">
                <property name="driver" value="com.mysql.jdbc.Driver"/>
                <property name="url" value="jdbc:mysql://localhost:3306/test?characterEncoding=utf-8"/>
                <property name="username" value="root"/>
                <property name="password" value="root"/>
            </dataSource>
        </environment>
    </environments>
    <mappers>
        <mapper resource="mapper/user.xml"/>
    </mappers>
</configuration>```

##### 测试
+ ```
String resource = "SqlMapConfig.xml";
        InputStream inputStream = Resources.getResourceAsStream(resource);
        SqlSessionFactory factory = new SqlSessionFactoryBuilder().build(inputStream);
        SqlSession sqlSession = factory.openSession();
        // 参数1 sql映射中的 namespace + "." + sqlId
        // 参数2为sql的参数
        User user = sqlSession.selectOne("test.findUserById", 1);
        System.out.println(user.toString());
        sqlSession.close();```

#### 理解
*基于sql语句的轻量级ORM框架，将sql语句写入配置文件映射中，进一步解耦，但是多了一步操作感觉比hibernate繁琐一些，但是比hibernate要快，有舍有得吧（为什么快还不知道，后续再看吧╮(╯▽╰)╭ ）*
