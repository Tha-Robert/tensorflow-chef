
# First, find out the compute capability of your GPU here: https://developer.nvidia.com/cuda-gpus
# E.g., 
# NVIDIA TITAN X	6.1
# GeForce GTX 1080	6.1
# GeForce GTX 970	5.2
#

group node.tensorflow.group do
  action :create
  not_if "getent group #{node.tensorflow.group}"
end


user node.tensorflow.user do
  action :create
  supports :manage_home => true
  home "/home/#{node.tensorflow.user}"
  shell "/bin/bash"
  not_if "getent passwd #{node.tensorflow.user}"
end

group node.tensorflow.group do
  action :modify
  members ["#{node.tensorflow.user}"]
  append true
end

# http://www.pyimagesearch.com/2016/07/04/how-to-install-cuda-toolkit-and-cudnn-for-deep-learning/
case node.platform_family
when "debian"

execute 'apt-get update -y'

  packages = %w{pkg-config zip g++ zlib1g-dev unzip swig git build-essential cmake unzip libopenblas-dev liblapack-dev linux-image-generic linux-image-extra-virtual linux-source linux-headers-generic }
  for script in packages do
    package script do
      action :install
    end
  end

when "rhel"

  package "gcc" do
    action :install
  end
  package "gcc-c++" do
    action :install
  end
  package "kernel-devel" do
    action :install
  end
  package "openssl" do
    action :install
  end
  package "openssl-devel" do
    action :install
  end
  package "openssl-libs" do
    action :install
  end
  package "python" do 
    action :install
  end
  package "python-pip" do 
    action :install
  end
  package "python-devel" do 
    action :install
  end
  package "python-lxml" do 
    action :install
  end
  package "python27-numpy" do
    action :install
  end
    
end


# On ec2 you need to disable the nouveau driver and reboot the machine
# http://www.pyimagesearch.com/2016/07/04/how-to-install-cuda-toolkit-and-cudnn-for-deep-learning/
#
template "/etc/modprobe.d/blacklist-nouveau.conf" do
  source "blacklist-nouveau.conf.erb"
  owner "root"
  mode 0775
end

tensorflow_compile "initram" do
 action :kernel_initramfs
end

# echo options nouveau modeset=0 | sudo tee -a /etc/modprobe.d/nouveau-kms.conf
# sudo update-initramfs -u
# sudo reboot



node.default.java.jdk_version = 8
node.default.java.set_etc_environment = true
node.default.java.oracle.accept_oracle_download_terms = true
include_recipe "java::oracle"

# bazel_installation('bazel') do
#   version '0.3.1'
#   action :create
# end

#
#
# HDFS support in tensorflow
# https://github.com/tensorflow/tensorflow/issues/2218
#
magic_shell_environment 'HADOOP_HDFS_HOME' do
  value "#{node.apache_hadoop.base_dir}"
end

magic_shell_environment 'LD_LIBRARY_PATH' do
  value "$LD_LIBRARY_PATH:$JAVA_HOME/jre/lib/amd64/server"
end

magic_shell_environment 'PATH' do
  value "$PATH:/usr/local/bin"
end


bash "install_numpy" do
    user "root"
    code <<-EOF
    pip install numpy 
EOF
end




if node.cuda.enabled == "true"

# Check to see if i can find a cuda card. If not, fail with an error



bash "test_nvidia" do
    user "root"
    code <<-EOF
    set -e
    lspci | grep -i nvidia
EOF
end
  cuda =  File.basename(node.cuda.url)
  base_cuda_dir =  File.basename(cuda, "_linux-run")
  cuda_dir = "/tmp/#{base_cuda_dir}"
  cached_file = "#{Chef::Config[:file_cache_path]}/#{cuda}"


  remote_file cached_file do
    source node.cuda.url
    mode 0755
    action :create
    retries 2
    ignore_failure true
    not_if { File.exist?(cached_file) }
  end

  remote_file cached_file do
    source node.cuda.url_backup
    mode 0755
    action :create
    retries 2
    not_if { File.exist?(cached_file) }
  end


  bash "unpack_install_cuda" do
    user "root"
    timeout 72000
    code <<-EOF
    set -e

    cd #{Chef::Config[:file_cache_path]}
    ./#{cuda} --silent --toolkit --driver --samples
EOF
    not_if { ::File.exists?( "/usr/local/cuda/version.txt" ) }
  end


#    cd #{cuda_dir}
#    ./NVIDIA-Linux-x86_64-352.39.run
#    modprobe nvidia
#    ./cuda-linux64-rel-#{node.cuda.version}-19867135.run
#    ./cuda-samples-linux-#{node.cuda.version}-19867135.run





  magic_shell_environment 'PATH' do
    value "$PATH:#{node.cuda.base_dir}/bin"
  end

  magic_shell_environment 'LD_LIBRARY_PATH' do
    value "#{node.cuda.base_dir}/lib64:$LD_LIBRARY_PATH"
  end

  magic_shell_environment 'CUDA_HOME' do
    value node.cuda.base_dir
  end


  tensorflow_compile "cuda" do
    action :cuda
  end

  base_cudnn_file =  File.basename(node.cudnn.url)
  base_cudnn_dir =  File.basename(base_cudnn_file, ".tgz")
  cudnn_dir = "/tmp/#{base_cudnn_dir}"
  cached_cudnn_file = "#{Chef::Config[:file_cache_path]}/#{base_cudnn_file}"


  bash "unpack_install_cdnn" do
    user "root"
    timeout 14400
    code <<-EOF
    set -e

    cd #{Chef::Config[:file_cache_path]}

    tar zxf #{cached_cudnn_file}
    cp -rf cuda/lib64 /usr
    cp -rf cuda/include/* /usr/include
    chmod a+r /usr/include/cudnn.h /usr/lib64/libcudnn*
# #{node.cuda.base_dir}

EOF
    #  not_if { ::File.exists?( "#{node.cuda.version_dir}/.cudnn_installed" ) }
    not_if { ::File.exists?( "/usr/include/cudnn.h" ) }
  end


  tensorflow_compile "cdnn" do
    action :cdnn
  end


end

package "expect" do
 action :install
end

# tensorflow_compile "tensorflow" do
#   action :tf
# end

# source $HADOOP_HOME/libexec/hadoop-config.sh
 # CLASSPATH=$($HADOOP_HDFS_HOME/bin/hdfs classpath --glob) python your_script.py


 tensorflow_install "cpu_install" do
   action :cpu_only
 end
