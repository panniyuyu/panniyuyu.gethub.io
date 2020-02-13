title: maven-assembly插件打zip包
author: YyWang
date: 2019-10-11 17:50:37
tags:
---
web工程通过maven打包通常都是war包，Tomcat会自动将war包解压并发布出来，但如果本身做的不是web工程，是普通java项目如何发布到服务器上并运行main方法呢？公司里使用maven-assembly这个插件，将项目打包成zip压缩包，里面包含bin、conf和lib三个文件夹，bin目录中保存启动和停止的shell脚本，conf中保存配置文件，lib目录中保存编译好的jar和所依赖的jar；然后将zip包抽取并解压到服务器启动start.sh脚本来运行java项目。

在这个过程中就用到了maven-assembly这个插件来进行编译并打包，步骤如下

目录结构

```
main
  |--assembly
         |----bin
               |---start.sh
               |---stop.sh
               |---jvm.properties
         |----assembly.xml
```

* 1. pom中配置assembly插件

```
<plugin>
	<groupId>org.apache.maven.plugins</groupId>
	<artifactId>maven-assembly-plugin</artifactId>
	<version>3.1.0</version>
	<configuration>
		<!--打包规则的配置-->
		<descriptors>
			<descriptor>src/main/assembly/assembly.xml</descriptor>
		</descriptors>
		<tarLongFileMode>posix</tarLongFileMode>
	</configuration>
	<executions>
		<execution>
			<id>make-assembly</id>
			<phase>package</phase>
			<goals>
				<goal>single</goal>
			</goals>
		</execution>
	</executions>
</plugin>
```

注：使用assembly插件编译要讲该插件的配置放在plugins标签中的第一个，在我的工程中开始在前面的时spring-boot-maven-plugin插件导致编译失败了

* 2.创建并配置assembly.xml文件

```
<assembly>

    <id>assembly</id>

    <formats>
        <format>zip</format>
        <format>dir</format>
    </formats>

    <includeBaseDirectory>false</includeBaseDirectory>

    <!--输出文件的配置  3个属性分别是 编译路径 输出路径 文件权限-->
    <fileSets>
        <fileSet>
            <directory>src/main/resources</directory>
            <outputDirectory>conf</outputDirectory>
            <fileMode>0644</fileMode>
        </fileSet>
        <fileSet>
            <directory>src/main/assembly/bin</directory>
            <outputDirectory>bin</outputDirectory>
            <includes>
                <include>start.sh</include>
                <include>stop.sh</include>
            </includes>
            <fileMode>0755</fileMode>
        </fileSet>
        <fileSet>
            <directory>src/main/assembly/bin</directory>
            <outputDirectory>bin</outputDirectory>
            <includes>
                <include>jvm.properties</include>
            </includes>
            <filtered>true</filtered>
            <fileMode>0644</fileMode>
        </fileSet>
    </fileSets>

    <dependencySets>
        <dependencySet>
            <outputDirectory>lib</outputDirectory>
        </dependencySet>
    </dependencySets>

</assembly>
```

* 3.编写脚本

start.sh

```
#!/bin/sh

BASEDIR=`dirname $0`/..
BASEDIR=`(cd "$BASEDIR"; pwd)`
echo current path:$BASEDIR

BASEBIN_DIR=$BASEDIR"/bin"
cd $BASEBIN_DIR

LAF_REG_INSTANCE="test-jsf-demo"
LOGPATH=""
LAF_REG_PIDPATH="$BASEBIN_DIR"

if [ "$1" != "" ] && [ "$2" != "" ]; then
    LAF_REG_INSTANCE="$1"
    LOGPATH="$2"
fi

if [ "$3" != "" ]; then
    LAF_REG_PIDPATH="$3"
fi


# ------ check if server is already running
PIDFILE=$LAF_REG_PIDPATH"/"$LAF_REG_INSTANCE"_startup.pid"
if [ -f $PIDFILE ]; then
    if kill -0 `cat $PIDFILE` > /dev/null 2>&1; then
        echo server already running as process `cat $PIDFILE`.
        exit 0
    fi
fi

# ------ set JAVACMD
# If a specific java binary isn't specified search for the standard 'java' binary
if [ -z "$JAVACMD" ] ; then
  if [ -n "$JAVA_HOME"  ] ; then
    if [ -x "$JAVA_HOME/jre/sh/java" ] ; then
      # IBM's JDK on AIX uses strange locations for the executables
      JAVACMD="$JAVA_HOME/jre/sh/java"
    else
      JAVACMD="$JAVA_HOME/bin/java"
    fi
  else
    JAVACMD=`which java`
  fi
fi

if [ ! -x "$JAVACMD" ] ; then
  echo "Error: JAVA_HOME is not defined correctly."
  echo "  We cannot execute $JAVACMD"
  exit 1
fi

# ------ set CLASSPATH
CLASSPATH="$BASEDIR"/conf/:"$BASEDIR"/root/:"$BASEDIR"/lib/*
echo "$CLASSPATH"

# ------ set jvm memory
sed "s/\r$//g" jvm.properties > 1.properties
mv 1.properties jvm.properties
if [ -z "$OPTS_MEMORY" ] ; then
    OPTS_MEMORY="`sed -n '1p' jvm.properties`"
fi
if [ "`sed -n '2p' jvm.properties`" != "" ] ; then
    JAVA_CMD="`sed -n '2p' jvm.properties`"
    if [ -f $JAVA_CMD ]; then
        JAVACMD=$JAVA_CMD
    fi
fi

#DEBUG_OPTS="-Xdebug -Xnoagent -Djava.compiler=NONE -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=8000"
#JPDA_OPTS="-agentlib:jdwp=transport=dt_socket,address=8000,server=y,suspend=n"
# ------ run proxy
nohup "$JAVACMD" $JPDA_OPTS \
  $OPTS_MEMORY $DEBUG_OPTS \
  -classpath "$CLASSPATH" \
  -Dbasedir="$BASEDIR" \
  -Dfile.encoding="UTF-8" \
  com.jd.testjsfdemo.TestjsfdemoApplication \
  > /Users/Logs/testjsfdemo_std.out &


# ------ wirte pid to file
if [ $? -eq 0 ]
then
    if /bin/echo -n $! > "$PIDFILE"
    then
        sleep 1
        echo STARTED SUCCESS
    else
        echo FAILED TO WRITE PID
        exit 1
    fi
#    tail -100f $LOGFILE
else
    echo SERVER DID NOT START
    exit 1
fi
```

stop.sh

```
#!/bin/sh
BASEDIR=`dirname $0`
BASEDIR=`(cd "$BASEDIR"; pwd)`
echo current path $BASEDIR

LAF_REG_INSTANCE="test-jsf-demo"
LAF_REG_PIDPATH="$BASEDIR"

if [ "$1" != "" ]; then
    LAF_REG_INSTANCE="$1"
fi

if [ "$2" != "" ]; then
    LAF_REG_PIDPATH="$2"
fi

PIDFILE=$LAF_REG_PIDPATH"/"$LAF_REG_INSTANCE"_startup.pid"
echo $PIDFILE

if [ ! -f "$PIDFILE" ]
then
    echo "no registry to stop (could not find file $PIDFILE)"
else
    kill $(cat "$PIDFILE")
    sleep 10
    kill -9 $(cat "$PIDFILE")
    rm -f "$PIDFILE"
    echo STOPPED
fi
exit 0

echo stop finished.
```

jvm.properties

```
-Xms1024m -Xmx1024m -Xmn400m
/Library/Java/JavaVirtualMachines/jdk1.8.0_181.jdk/Contents/Home/bin/java
```

* 4.编译后就成功啦，之后在jdos上配置一下就可以自动部署了