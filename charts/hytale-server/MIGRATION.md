# Hytale Server Migration Guide

This guide explains how to migrate your existing Hytale server data to a new server managed by the Hytale Server Helm Chart.

## Prerequisites

*   You have `kubectl` installed and configured to connect to your Kubernetes cluster.
*   You have an existing Hytale server with data you want to migrate.
*   You have a PersistentVolumeClaim (PVC) with your Hytale server data.

## Migration Steps

### 1. Find the name of your existing PVC

First, you need to find the name of the PersistentVolumeClaim that your existing Hytale server uses. You can list all PVCs in your namespace with the following command:

```bash
kubectl get pvc
```

Identify the name of the PVC that contains your Hytale server data.

### 2. Update the `migration-pod.yaml`

Open the `migration-pod.yaml` file and replace `<DEIN-PVC-NAME>` with the actual name of your PVC that you found in the previous step.

For example, if your PVC is named `my-hytale-server-data`, the file should look like this:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: hytale-server-migration
spec:
  containers:
  - name: migration-container
    image: busybox
    command: ["/bin/sh", "-c", "sleep 3600"]
    volumeMounts:
    - name: hytale-data
      mountPath: /data
  volumes:
  - name: hytale-data
    persistentVolumeClaim:
      claimName: my-hytale-server-data
```

### 3. Deploy the migration pod

Now, deploy the migration pod to your Kubernetes cluster:

```bash
kubectl apply -f migration-pod.yaml
```

This will create a new pod named `hytale-server-migration` that mounts your existing PVC at `/data`.

### 4. Access the migration pod

Once the pod is running, you can get a shell inside the container:

```bash
kubectl exec -it hytale-server-migration -- /bin/sh
```

You are now inside the migration pod. Your Hytale server data is available in the `/data` directory.

### 5. Install and deploy the new Hytale Server via Helm

Install the Hytale Server Helm chart in the same namespace. Make sure that the `persistence.existingClaim` value in your `values.yaml` is set to the name of your PVC.

Example `values.yaml`:
```yaml
persistence:
  enabled: true
  existingClaim: <DEIN-PVC-NAME> # Replace with your PVC name
  ...
```

Then install the chart:

```bash
helm install hytale-server ./charts/hytale-server -f values.yaml
```

The new Hytale server pod will now start and use your existing data.

### 6. Clean up

After you have successfully migrated your data and the new Hytale server is running correctly, you can delete the migration pod:

```bash
kubectl delete pod hytale-server-migration
```

You have now successfully migrated your Hytale server data.
