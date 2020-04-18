title: MyBatis入门（续）-CRUD
author: YyWang
tags: MyBatis
categories: MyBatis
date: 2019-07-12 16:04:18
---
#### 根据用户名查询
+ ```
<select id="findUserByName" parameterType="java.lang.String" resultType="com.example.mybatisdemo.bean.User">
        SELECT * FROM users WHERE name = #{VALUE}
    </select>```
+ ```
sqlSession.selectOne("test.findUserByName", "yywang")```

#### 模糊查询，返回多个值
+ ```
<select id="findUserLikeName" parameterType="java.lang.String" resultType="com.example.mybatisdemo.bean.User">
        SELECT * FROM users WHERE name like #{VALUE}
    </select>```
+ ```
sqlSession.selectList("test.findUserLikeName", "%yy%");```

查询的resutlType分三种情况
* 基本类型：resultType="基本类型"
* List类型：resultType="List集合中的元素类型"
* Map类型：
	* 单条记录 resultType="java.util.Map"
    * 多条记录 resultType="Map中value的类型"



#### 添加数据
+ ```
<insert id="insertUser" parameterType="com.example.mybatisdemo.bean.User">
        <selectKey keyProperty="id" order="AFTER" resultType="int">
            SELECT LAST_INSERT_ID()
        </selectKey>
        INSERT into users(uname,sex,age,udesc) values (#{uname},#{sex},#{age},#{udesc})
    </insert>```
+ ```
 User user = new User("bangni","female",22,"tc");
 sqlSession.commit(); // 必加```
 ##### tips
 - *selectKey* 用来配置返回主键 
 - *keyProperty*  表中主键的名称
 - *order* 表示SELECT LAST_INSERT_ID()在insert语句发生的顺序，after意为insert执行之后返回，用于自增主键，UUID的方式可以配置为before
 - *resultType* 返回值类型
 
 ***注1：sql语句中有多个参数，占位符#{}也需要指定不同的表示方式，如上#{uname},#{sex}等***
 
 ***注2：sql没问题运行报错，因为之前的数据表设计问题，name和desc是关键字，这里开始做了修改***
 
 ***注3：修改之后运行通过，数据库查不到记录，想到之前测试Junit回自动回滚，于是添加@Rollback注解导入依赖后还是无果，最终加上session.commit()解决，由于MyBatis接管了JDBC的事务管理器，JDBC回自动提交而MyBatis不会，这里需要自行手动提交，修改删除同样***
 
#### 删除
+ ```
<delete id="delUserById" parameterType="int">
        delete from users where id = #{id}
    </delete>
```
+ ```
sqlSession.delete("test.delUserById",3);
  sqlSession.commit();```
  
#### 更新
+ ```
<update id="updateUserById" parameterType="int">
        update users set age = 0 where id = #{id}
    </update>```
+ ```
sqlSession.update("test.updateUserById",8);
  sqlSession.commit();```
  
#### 查看最后执行的SQL
只需在配置文件中添加配置即可打印查询语句
```
<configuration>
    <settings>
        <setting name="logImpl" value="STDOUT_LOGGING" />
    </settings>
</configuration>
```