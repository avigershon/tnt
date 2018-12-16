
# Step 1: Create EKS Cluster
# Step 1.1: create IAM role
# Step 2: Create EC2 Instance with kubectl configured
# Step 3: Launch and Configure Amazon EKS Worker Nodes
#   - s3 location : https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-07-26/amazon-eks-nodegroup.yaml
#   - Stack name : Ashford-Worker-Nodes-(n)
#   - ClusterControlPlaneSecurityGroup : DataTeam_Rules
#   - Node image : ami-dea4d5a1
#   - KeyName : data_team_key
#   - VPC : vpc-888730ec
#   - Subnets : NGW-subnet
#   - After it complete get the NodeIntanceRole arn
# Step 4: enable worker nodes to join your cluster
#   - curl -O https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-07-26/aws-auth-cm.yaml
#   - change the Node intance role with the one you got above
#   - aws cloudformation describe-stack-instance --stack-set-name ashford_3
#   - kubectl apply -f aws-auth-cm.yaml
# Step 5: install helm (we need to add inbound so helm client can work with tiller server)

while [ $# -gt 0 ]; do

   if [[ $1 == *"--"* ]]; then
        v="${1/--/}"
        declare $v="$2"
   fi

  shift
done

setup () {

  #env=$1;
  #recreate=$2;
  home=$PWD;
  commit_hash=$(git log --format="%H" -n 1);
  branch=$(git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e "s/* \(.*\)/\1/");

  rm -rf $home/environments;

  #create env folders
  mkdir $home/environments;
  mkdir $home/environments/$branch;
  mkdir $home/environments/$branch/packages;
  mkdir $home/environments/$branch/packages/charts;
  mkdir $home/environments/$branch/packages/charts/global;

  #if [ "$recreate" == "true" ]; then
  system_setup
  #else
  #  kubectl create namespace $env;
  #  install_chart $env
  #fi

  chart_path="charts"
  install_charts $branch $commit_hash $chart_path $home

}

system_setup () {

    home=$PWD
    chart_path="cluster"

    ACCOUNT=$(gcloud info --format='value(config.account)')

    kubectl create clusterrolebinding owner-cluster-admin-binding \
       --clusterrole cluster-admin \
       --user $ACCOUNT

    #kubectl apply -f $home/rolebinding.yaml -o yaml
    #kubectl apply -f $home/pv.yaml -o yaml

    #aws eks describe-cluster --name Ashford_two --query cluster.status
    #aws eks describe-cluster --name Ashford_two --query cluster.endpoint
    #aws eks describe-cluster --name Ashford_two --query cluster.certificateAuthority.data

    kubectl create serviceaccount dashboard -n default

    kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml

    # echo 'export PATH=$HOME/bin:$PATH' >> ~/.bashrc

    curl https://raw.githubusercontent.com/kubernetes/helm/master/scripts/get > get_helm.sh;
    chmod +x get_helm.sh;

    # export PATH=$PATH:/usr/local/bin;
    ./get_helm.sh;
    helm init --wait --upgrade;
    wait_for_tiller
    kubectl create serviceaccount --namespace kube-system tiller
    wait_for_tiller
    kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
    wait_for_tiller
    kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'
    wait_for_tiller

    kubectl create serviceaccount --namespace kube-system tiller
    kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
    kubectl patch deploy --namespace kube-system tiller-deploy -p '{"spec":{"template":{"spec":{"serviceAccount":"tiller"}}}}'

    helm repo add incubator http://storage.googleapis.com/kubernetes-charts-incubator
    helm repo add stable http://storage.googleapis.com/kubernetes-charts

    kubectl create secret docker-registry dbar1 --docker-server=docker.io --docker-username=dbar1 --docker-password=Dedi123$% --docker-email=dbar@ashford.com

}

wait_for_tiller()
{
    state=true
    while $state ; do
    echo "Waitting for Tiller..."
    result=$( kubectl get pods --all-namespaces | egrep  "kube-system.*tiller.*Running.*[1-9][m,h,d]")
    #echo "DEBUG: Result found is $result"
    if [ -n "$result" ] ; then
        echo "####################"
        echo "### COMPLETE !!! ###"
        echo "####################"
        kubectl get pods --all-namespaces
        state=false
    fi
    sleep 1
    done
}

install_charts() {

  branch=$1
  commit_hash=$2
  path=$3
  home=$4

  cd $home
  project=${PWD##*/}
  env=$project-$branch;

  if [ "$path" == "cluster" ]; then
      namespace="default";
  else
      namespace=$project-$branch;
  fi

  kubectl create namespace $namespace;
  #kubectl config set-context $(kubectl config current-context) --namespace=$namespace;

  cd $home/$path/;

  for chart in * ; do
      mkdir $home/environments/$branch/packages/$path;
      mkdir $home/environments/$branch/packages/$path/$chart;
      echo "packaging $chart chart...";
      helm package $chart -d "$home/environments/$branch/packages/$path/$chart";
  done

  cd $home/environments/$branch/packages/$path;

  echo "current folder=$PWD";

  for chart in * ; do

    #release_name=$namespace-$chart;
    release_name=$chart;

    cd $home/environments/$branch/packages/$path/$chart;

    echo "current folder=$PWD";

    for package in * ; do
      #if [ "$chart" != "cluster" ]; then
         upgrade_chart $chart $package $namespace $release_name $env|| install_chart $chart $package $namespace $release_name $env
      #fi
      #if [ "$recreate" == "true" ]; then
      #  install_chart $chart $package $namespace
      #else
      #  upgrade_chart $chart $package $namespace || install_chart $chart $package $namespace
      #fi

    done

  done
}

install_chart () {
   chart=$1
   package=$2
   namespace=$3
   release_name=$4
   env=$5

   echo "helm del $chart --purge";
   helm del $chart --purge;

   echo "helm install $package --name $release_name --namespace $namespace --wait --set project=$env";
   helm install $package --name $release_name --namespace $namespace --wait --set project=$env;
}

upgrade_chart () {
   chart=$1
   package=$2
   namespace=$3
   release_name=$4
   env=$5

   echo "helm upgrade $release_name $package -i --namespace $namespace --wait --set project=$env";
   helm upgrade $release_name $package -i --namespace $namespace --wait --set project=$env;
}

package_and_install_chart () {

   path=`dirname "$1"`
   chart=`basename "$1"`

   project=${PWD##*/}
   branch=$(git branch --no-color 2> /dev/null | sed -e '/^[^*]/d' -e "s/* \(.*\)/\1/");
   env=$project-$branch;

   home=$PWD
   namespace="default";

   echo "********************$PWD******************************";

   #if [ "$path" == "cluster" ]; then
   #  namespace="default";
   #else
   #  namespace=$project-$branch;
   #fi

   #kubectl create namespace $namespace;

   cd $home/$path/;
   echo "********************$PWD******************************";

   rm -rf $home/environments/$branch/packages/$path/$chart;

   mkdir $home/environments;
   mkdir $home/environments/$branch;
   mkdir $home/environments/$branch/packages;
   mkdir $home/environments/$branch/packages/$path;
   mkdir $home/environments/$branch/packages/$path/$chart;

   echo "packaging $chart chart...";
   helm package $chart -d "$home/environments/$branch/packages/$path/$chart";
   echo "helm package $chart -d $home/environments/$branch/packages/$path/$chart";

   release_name=$chart;

   cd $home/environments/$branch/packages/$path/$chart;

   echo "current folder=$PWD";

   echo "********************$PWD******************************";

   for package in * ; do
      echo "********************$PWD******************************";

      echo "chart=$chart ,package=$package ,namespace=$namespace ,release_name=$release_name ,env=$env";
      upgrade_chart $chart $package $namespace $release_name $env|| install_chart $chart $package $namespace $release_name $env
   done
}

aws_create_cluster () {

    # ./setup-aws.sh --ClusterControlPlaneSecurityGroup sg-20459f57 --ClusterName ashford_4 --KeyName data_team_key --NodeAutoScalingGroupMaxSize 3 --NodeAutoScalingGroupMinSize 1 --NodeImageId ami-dea4d5a1 --NodeInstanceType t2.medium --Subnets subnet-844d51dd,subnet-2f21db59 --VpcId vpc-888730ec

   cleanClusterName=${ClusterName/_/-}
   cleanSubnets="${Subnets//,/\\,}"
   stackName=eks-$cleanClusterName-worker-nodes

   accountID=$( aws sts get-caller-identity --query 'Account' --output text)
   eksRole=$( aws iam get-role --role-name EKS_Role --query 'Role.RoleName' --output text)
   clusterStatus=$( aws eks describe-cluster --name $cleanClusterName --query 'cluster.status' --output text)
   workersStackStatus=$( aws cloudformation describe-stacks --stack-name $stackName --query 'Stacks[*].StackStatus' --output text)

   if [ "$eksRole" = "EKS_Role" ]; then
      echo "EKS_Role already exists"
   else
      echo "EKS_Role doesn't exists, it will be created"
   fi

   if [ "$clusterStatus" != "ACTIVE" ]; then

      echo "Setp 1 -- AWS setup - Creating Cluster $cleanClusterName "
      aws eks create-cluster --name $cleanClusterName --role-arn arn:aws:iam::$accountID:role/$eksRole --resources-vpc-config subnetIds=$Subnets,securityGroupIds=$ClusterControlPlaneSecurityGroup

      while [[ "$clusterStatus" != "ACTIVE" ]];do
          clusterStatus=$( aws eks describe-cluster --name $cleanClusterName --query 'cluster.status' --output text)
          echo "Setp 1 -- AWS setup - Cluster $cleanClusterName is in state $clusterStatus"
          sleep 0.1
      done
   fi

   if [ "$workersStackStatus" != "CREATE_COMPLETE" ]; then

      echo "Step 2 -- AWS setup - Creating EKS worker nodes"

      aws cloudformation create-stack --stack-name $stackName --template-url https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-07-26/amazon-eks-nodegroup.yaml --parameters ParameterKey=ClusterControlPlaneSecurityGroup,ParameterValue=$ClusterControlPlaneSecurityGroup ParameterKey=ClusterName,ParameterValue=$ClusterName ParameterKey=KeyName,ParameterValue=$KeyName ParameterKey=NodeAutoScalingGroupMaxSize,ParameterValue=$NodeAutoScalingGroupMaxSize ParameterKey=NodeAutoScalingGroupMinSize,ParameterValue=$NodeAutoScalingGroupMinSize ParameterKey=NodeGroupName,ParameterValue=$ClusterName-node-group ParameterKey=NodeImageId,ParameterValue=$NodeImageId ParameterKey=NodeInstanceType,ParameterValue=$NodeInstanceType ParameterKey=VpcId,ParameterValue=$VpcId ParameterKey=Subnets,ParameterValue=$cleanSubnets --capabilities CAPABILITY_IAM

      while [[ "$workersStackStatus" != "CREATE_COMPLETE" ]];do
          workersStackStatus=$( aws cloudformation describe-stacks --stack-name $stackName --query 'Stacks[*].StackStatus' --output text)
          echo "Setp 1 -- AWS setup - CloudFormation Stack $stackName is in state $workersStackStatus"
          sleep 0.1
      done
   fi

   hasAuthenticator=$( aws-iam-authenticator token -i $cleanClusterName | python3 -c "import sys, json; print(json.load(sys.stdin)['kind'])")
   if [ "$hasAuthenticator" != "ExecCredential" ]; then
      echo "Step 3 -- Client setup - Installing aws-iam-authenticator"
      curl -o aws-iam-authenticator "https://amazon-eks.s3-us-west-2.amazonaws.com/1.10.3/2018-07-26/bin/linux/amd64/aws-iam-authenticator";
      chmod +x ./aws-iam-authenticator;
      cp ./aws-iam-authenticator /usr/bin/aws-iam-authenticator;

      aws-iam-authenticator token -i $cleanClusterName;
   else
      echo "Step 3 -- Client setup - aws-iam-authenticator is already installed"
   fi

   echo "Step 4 -- Client setup - Configuring kubectl"

   mkdir -p ~/.kube;
   mkdir -p ~/.kube/$cleanClusterName;

   /bin/cat <<EOM >~/.kube/$cleanClusterName/config
apiVersion: v1
clusters:
- cluster:
    server: $( aws eks describe-cluster --name $cleanClusterName --query cluster.endpoint)
    certificate-authority-data: $( aws eks describe-cluster --name $cleanClusterName --query cluster.certificateAuthority.data)
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "$cleanClusterName"
      #  - "-r"
      #  - "arn:aws:iam::583658998514:role/EKS_Role"
      #env:
      #  - name: AWS_PROFILE
      #    value: "ashford"
EOM

   echo "Step 4 -- Client setup - Updating KUBECONFIG"
   export KUBECONFIG=~/.kube/$cleanClusterName/config;
   cp ~/.kube/$cleanClusterName/config ~/.kube/config
   echo "export KUBECONFIG=~/.kube/$cleanClusterName/config" >> ~/.bashrc
   echo "Step 4 -- Client setup - Creating AWS auth configmap"
   /bin/cat <<EOM >~/.kube/$cleanClusterName/aws-auth-cm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: aws-auth
  namespace: kube-system
data:
  mapRoles: |
    - rolearn:  $( aws cloudformation describe-stacks --stack-name eks-$cleanClusterName-worker-nodes --query 'Stacks[*].Outputs[*].OutputValue' --output text)
      username: system:node:{{EC2PrivateDNSName}}
      groups:
        - system:bootstrappers
        - system:nodes
EOM

   kubectl apply -f ~/.kube/$cleanClusterName/aws-auth-cm.yaml;

   echo "Step 5 -- Client setup - Finished setup Kuberntes Cluster on AWS"

   ./bootstrap-aws.sh

   echo "Step 6 -- cluster setup - Finished to install charts on the cluster"

}

aws_switch_cluster () {

   cleanClusterName=$ClusterName

   mkdir -p ~/.kube;
   mkdir -p ~/.kube/$cleanClusterName;

   /bin/cat <<EOM >~/.kube/$cleanClusterName/config
apiVersion: v1
clusters:
- cluster:
    server: $( aws eks describe-cluster --name $cleanClusterName --query cluster.endpoint)
    certificate-authority-data: $( aws eks describe-cluster --name $cleanClusterName --query cluster.certificateAuthority.data)
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "$cleanClusterName"
      env: null
EOM

   echo "Client setup - Updating KUBECONFIG"

   export KUBECONFIG=~/.kube/$cleanClusterName/config;
   cp ~/.kube/$cleanClusterName/config ~/.kube/config
   echo "export KUBECONFIG=~/.kube/$cleanClusterName/config" >> ~/.bashrc
   echo "source aws_bash_completer" >> ~/.bashrc
   }

if [ ${help+x} ]; then
    cat <<HELP
Usage: setup-aws.sh [OPTION]
Configure, Install, Create Kubernetes environment in AWS EKS and local kubectl config file.

Options:
    --ClusterName=EKS_Cluster_Name	Will set witch cluster name we use for the creation or configuration
    --ClusterControlPlaneSecurityGroup=AWS_Security_Group	Mandatory option for EKS Cluster creation. AWS_Security_Group needs to exist in AWS (The setup-aws script will not create it)
    --KeyName=AWS_Pem_Key 	Like with security group, the script will not create the key
    --NodeAutoScalingGroupMaxSize=NUMBER    Mandatory for creation, the node auto-scaling group max size is used for the cloud formation
    --NodeAutoScalingGroupMinSize=NUMBER    Mandatory for creation, the node auto-scaling group min size is used for the cloud formation
    --NodeImageId=IMAGE Mandatory for creation,
    --NodeInstanceType=EC2_INSTANCE_TYPE    Mandatory for creation. ex: t2.medium
    --Subnets=AWS_SUBNET[,AWS_SUBNET]    Mandatory for creation
    --VpcId=AWS_VPC Mandatory for creation
    --SwitchOnly    Will configure then local kubectl config file to switch to --ClusterName value
    --chart=PACKAGE   Will install the chart PACKAGE


Example:
    Creation of a new EKS Cluster:

./setup-aws.sh --ClusterControlPlaneSecurityGroup sg-20459f57 --ClusterName ashford --KeyName data_team_key --NodeAutoScalingGroupMaxSize 3 --NodeAutoScalingGroupMinSize 1 --NodeImageId ami-dea4d5a1 --NodeInstanceType t2.medium --Subnets subnet-2f21db59,subnet-1a27dd6c,subnet-a0d085e8,subnet-844d51dd,subnet-0f485456 --VpcId vpc-888730ec

    Chart package installation

./setup-aws.sh --chart charts/default
./setup-aws.sh --chart charts/nginx-ingress
./setup-aws.sh --chart charts/filebeat
./setup-aws.sh --chart charts/elasticsearch
./setup-aws.sh --chart charts/logstash
./setup-aws.sh --chart charts/kafka
./setup-aws.sh --chart charts/kafka-client
./setup-aws.sh --chart charts/schema-registry
./setup-aws.sh --chart charts/nifi

    Configure a kubectl on an existing cluster

./setup-aws.sh --ClusterName ashford --SwitchOnly

HELP
else
    if [ -z ${chart+x} ]; then
        echo "chart is not set";
    if [ -z ${ClusterName+x} ]; then
        echo "ClusterName is not set";
        system_setup;
    else
        echo "ClusterName is set";
        if [ -z ${SwitchOnly+x} ]; then
            echo "Prepering to create new cluster $ClusterName";
            aws_create_cluster $ClusterName;
        else
            echo "Switching to $ClusterName";
            aws_switch_cluster $ClusterName;
        fi
    fi
    else
        echo "chart is set";
        package_and_install_chart $chart;
    fi
fi
