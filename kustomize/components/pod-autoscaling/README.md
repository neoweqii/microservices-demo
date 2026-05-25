# Enable pod autoscaling

This component adds `HorizontalPodAutoscaler` resources for:

- `frontend`
- `currencyservice`
- `recommendationservice`

These services are good autoscaling targets for Online Boutique:

- `frontend` is where your external traffic lands.
- `currencyservice` is a hot path service that is called frequently by the frontend and is often one of the first backends to feel load.
- `recommendationservice` participates in user-facing browse flows and can become busy during catalog and cart activity.

## Prerequisites

- A Kubernetes cluster with the `metrics.k8s.io` API available, usually through `metrics-server`.
- The default CPU `requests` already present in Online Boutique manifests. HPA CPU targets depend on those requests.

You can confirm metrics are available with:

```bash
kubectl top pods
```

## Use this component

From the `kustomize/` folder at the root level of this repository, execute this command:

```bash
kustomize edit add component components/pod-autoscaling
```

This will update the `kustomize/kustomization.yaml` file which could be similar to:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- base
components:
- components/pod-autoscaling
```

You can then deploy Online Boutique and this component to your cluster using `kubectl apply -k .`. If you just want to render the YAML manifest without deploying to your cluster, run `kubectl kustomize .`.

## Testing through an external load balancer

If your traffic comes from a load balancer container running on a VM, that is fine. HPA reacts to pod resource usage, not to where the traffic originated from.

Use this path:

1. Send traffic from the VM load balancer to the application entrypoint, typically `frontend-external`.
2. Observe the HPA and pod counts in the cluster.
3. Increase traffic until CPU utilization rises above the HPA target.

Useful commands:

```bash
kubectl get hpa -w
kubectl get pods -l app=frontend -w
kubectl get pods -l app=currencyservice -w
kubectl get pods -l app=recommendationservice -w
kubectl top pods
```

## Using the built-in loadgenerator

If you want a quick in-cluster test, the built-in `loadgenerator` can already generate enough traffic to trigger HPA once you raise its settings.

Example:

```bash
kubectl set env deployment/loadgenerator USERS=200 RATE=20
```

The default manifest points the load generator at `frontend:80`, which is enough to test autoscaling behavior inside the cluster.

If you specifically want to exercise the external path through your VM load balancer, keep the load generator outside the cluster or change `FRONTEND_ADDR` to your external address.
