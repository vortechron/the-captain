run: helm install mysql bitnami/mysql

helm install mysql bitnami/mysql \
--set primary.resources.limits.memory=1.5Gi \
--set primary.resources.requests.memory=1Gi \
--set image.tag=8.0

ALTER USER 'forge'@'%' IDENTIFIED WITH mysql_native_password BY 'RDhcHICH57ZAwZISmzNc';
FLUSH PRIVILEGES;

to port forward: k port-forward svc/mysql 33061:3306

Did you know there are enterprise versions of the Bitnami catalog? For enhanced secure software supply chain features, unlimited pulls from Docker, LTS support, or application customization, see Bitnami Premium or Tanzu Application Catalog. See https://www.arrow.com/globalecs/na/vendors/bitnami for more information.

** Please be patient while the chart is being deployed **

Tip:

  Watch the deployment status using the command: kubectl get pods -w --namespace default

Services:

  echo Primary: mysql.default.svc.cluster.local:3306

Execute the following to get the administrator credentials:

  echo Username: root
  MYSQL_ROOT_PASSWORD=$(kubectl get secret --namespace default mysql -o jsonpath="{.data.mysql-root-password}" | base64 -d)

To connect to your database:

  1. Run a pod that you can use as a client:

      kubectl run mysql-client --rm --tty -i --restart='Never' --image  docker.io/bitnami/mysql:8.4.4-debian-12-r4 --namespace default --env MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD --command -- bash

  2. To connect to primary service (read/write):

      mysql -h mysql.default.svc.cluster.local -uroot -p"$MYSQL_ROOT_PASSWORD"

  3. or port forward

      k port-forward svc/mysql 33066:3306

      mysql -h localhost -uroot -p"$MYSQL_ROOT_PASSWORD"
