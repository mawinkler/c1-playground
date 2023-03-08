Secrets stored inside the images.
It is always recommended to ensure that, no sensitive information is stored in the environment file or in the code. Unfortunately, most of the developers are not aware of the risks associated with this and they end up storing sensitive data in the environment leading to attacks on docker systems.

We have already seen a scenario where secrets stored in the environment variables can easily be found if an attacker manages to get access to a container.

We can use tools like Trufflehog or other secret finders to catch secrets. Ideally, we should be using secrets management system like Hashicorp Vault or AWS KMS to store and use short-lived secrets.

Let us try to understand and exploit such a scenario

Lets create a vulnerable image and try to exploit it

 FROM nginx
 RUN useradd guest
 RUN echo "root:root" | chpasswd
 USER guest
As you can see from the above Dockerfile that we are trying to change the password to root while building the image.

Let’s try to build the image out of the Dockerfile by typing the below command in the terminal

$ docker build -t vulimage .

Let’s try to run the container from the image

$ docker run --rm -it vulimage sh

$ whoami

You can see we have currently logged in as the guest user

Now try to get out of the container shell by typing exit and try to investigate the image as a security engineer.

Type the below command in the terminal of the host to list the available images in the host.

$ docker history vulimage

IMAGE          CREATED              CREATED BY                                      SIZE      COMMENT
e1c0a7b2193f   About a minute ago   USER guest                                      0B        buildkit.dockerfile.v0
<missing>      About a minute ago   RUN /bin/sh -c echo "root:root" | chpasswd #…   627B      buildkit.dockerfile.v0
<missing>      About a minute ago   RUN /bin/sh -c useradd guest # buildkit         329kB     buildkit.dockerfile.v0
<missing>      2 weeks ago          /bin/sh -c #(nop)  CMD ["nginx" "-g" "daemon…   0B        
<missing>      2 weeks ago          /bin/sh -c #(nop)  STOPSIGNAL SIGQUIT           0B        
<missing>      2 weeks ago          /bin/sh -c #(nop)  EXPOSE 80                    0B        
<missing>      2 weeks ago          /bin/sh -c #(nop)  ENTRYPOINT ["/docker-entr…   0B        
<missing>      2 weeks ago          /bin/sh -c #(nop) COPY file:e57eef017a414ca7…   4.62kB    
<missing>      2 weeks ago          /bin/sh -c #(nop) COPY file:abbcbf84dc17ee44…   1.27kB    
<missing>      2 weeks ago          /bin/sh -c #(nop) COPY file:5c18272734349488…   2.12kB    
<missing>      2 weeks ago          /bin/sh -c #(nop) COPY file:7b307b62e82255f0…   1.62kB    
<missing>      2 weeks ago          /bin/sh -c set -x     && addgroup --system -…   61.3MB    
<missing>      2 weeks ago          /bin/sh -c #(nop)  ENV PKG_RELEASE=1~bullseye   0B        
<missing>      2 weeks ago          /bin/sh -c #(nop)  ENV NJS_VERSION=0.7.9        0B        
<missing>      2 weeks ago          /bin/sh -c #(nop)  ENV NGINX_VERSION=1.23.3     0B        
<missing>      2 weeks ago          /bin/sh -c #(nop)  LABEL maintainer=NGINX Do…   0B        
<missing>      2 weeks ago          /bin/sh -c #(nop)  CMD ["bash"]                 0B        
<missing>      2 weeks ago          /bin/sh -c #(nop) ADD file:3ea7c69e4bfac2ebb…   80.5MB 


$ docker run --rm -it vulimage sh

Now get into the root shell by typing the su command. During password prompt enter the password as root inside the container

$ su root
Password: 
root@ca9e72b8aacb:/# 
