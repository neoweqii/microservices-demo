# GitHub Actions Workflows

This page describes the CI/CD workflows for the Online Boutique app, which run in [Github Actions](https://github.com/GoogleCloudPlatform/microservices-demo/actions).

## Infrastructure

The CI/CD pipelines for Online Boutique run in Github Actions, using a pool of two [self-hosted runners]((https://help.github.com/en/actions/automating-your-workflow-with-github-actions/about-self-hosted-runners)). These runners are GCE instances (virtual machines) that, for every open Pull Request in the repo, run the code test pipeline, deploy test pipeline, and (on main) deploy the latest version of the app to [cymbal-shops.retail.cymbal.dev](https://cymbal-shops.retail.cymbal.dev)

We also host a test GKE cluster, which is where the deploy tests run. Every PR has its own namespace in the cluster.

## Workflows

**Note**: In order for the current CI/CD setup to work on your pull request, you must branch directly off the repo (no forks). This is because the Github secrets necessary for these tests aren't copied over when you fork.

### Code Tests - [ci-pr.yaml](ci-pr.yaml)

These tests run on every commit for every open PR, as well as any commit to main / any release branch. Currently, this workflow runs only Go unit tests.


### Deploy Tests- [ci-pr.yaml](ci-pr.yaml)

These tests run on every commit for every open PR, as well as any commit to main / any release branch. This workflow:

1. Creates a dedicated GKE namespace for that PR, if it doesn't already exist, in the PR GKE cluster.
2. Uses `skaffold run` to build and push the images specific to that PR commit. Then skaffold deploys those images, via `kubernetes-manifests`, to the PR namespace in the test cluster.
3. Tests to make sure all the pods start up and become ready.
4. Gets the LoadBalancer IP for the frontend service.
5. Comments that IP in the pull request, for staging.

In forks, these Google Cloud deployment tests are usually not available. In this repo they are disabled by default and can be re-enabled with the repository variable `ENABLE_GCP_DEPLOYMENT_TESTS=true`.

### Push and Deploy Latest - [push-deploy](push-deploy.yml)

This is the Continuous Deployment workflow, and it runs on every commit to the main branch. This workflow:

1. Builds the container images for every service, tagging as `latest`.
2. Pushes those images to Google Container Registry.

Note that this workflow does not update the image tags used in `release/kubernetes-manifests.yaml` - these release manifests are tied to a stable `v0.x.x` release.

### Self-hosted Kubernetes CD - [cd-self-hosted.yaml](cd-self-hosted.yaml)

This workflow deploys the fork to your own Kubernetes cluster from a self-hosted runner. It runs automatically after a successful `Continuous Integration - Main/Release` workflow on `main`, and can also be started manually.

It performs the following steps:

1. Builds and pushes the application images to GitHub Container Registry (`ghcr.io/<owner>/<repo>/<service>`). By default each service image is tagged from the Git tree hash of its own build context, so unchanged services are reused across commits instead of being rebuilt. It also updates `latest`.
   The workflow then prints a per-service summary showing which images were `rebuilt` and which were `reused`.
2. Writes the `CD_KUBECONFIG` secret to the runner and optionally switches to `CD_K8S_CONTEXT`.
3. Generates a temporary Kustomize overlay that points the Kubernetes manifests to the computed `ghcr.io` image paths and the per-service tags discovered during the build step.
4. Applies the manifests into the configured namespace and waits for all deployments to roll out.

Required repository configuration:

- Optional variable `CD_K8S_NAMESPACE` (defaults to `online-boutique`)
- Optional variable `CD_K8S_CONTEXT` when the kubeconfig contains more than one context
- Optional variable `CD_INCLUDE_LOADGENERATOR=true` to deploy the loadgenerator service
- Secret `CD_KUBECONFIG`

Manual dispatch note:

- `image_tag` remains available as a shared override when you want every service to deploy from the same prebuilt tag.

GitHub Packages / GHCR details:

- The workflow logs in to `ghcr.io` with `${{ github.actor }}` and `${{ secrets.GITHUB_TOKEN }}`, so no extra registry username/password secrets are required.
- The registry path is derived automatically from the repository metadata and normalized to lowercase.
- After the first successful push, open the package list in GitHub and mark each published container package as `Public`.
- If the packages remain private, Kubernetes pods will fail with `ImagePullBackOff` until you add an `imagePullSecret` flow.

Runner prerequisites:

- A Linux self-hosted runner with `bash`, `docker`, and `kubectl`
- Access from the runner to the target Kubernetes API and `ghcr.io`

### Cleanup - [cleanup.yaml](cleanup.yaml)

This workflow runs when a PR closes, regardless of whether it was merged into main. This workflow deletes the PR-specific GKE namespace in the test cluster.

## Appendix - Creating a new Actions runner

Should one of the two self-hosted Github Actions runners (GCE instances) fail, or you want to add more runner capacity, this is how to provision a new runner. Note that you need IAM access to the admin Online Boutique GCP project in order to do this.

1. Create a GCE instance.
    - VM should be at least n1-standard-4 with 50GB persistent disk
    - VM should use custom service account with permissions to: access a GKE cluster, create GCS storage buckets, and push to GCR.
2. SSH into new VM through the Google Cloud Console.
3. Install project-specific dependencies, including go, docker, skaffold, and kubectl:

```
wget -O - https://raw.githubusercontent.com/GoogleCloudPlatform/microservices-demo/main/.github/workflows/install-dependencies.sh | bash
```

The instance will restart when the script completes in order to finish the Docker install.

4. SSH back into the VM.

5. Follow the instructions to add a new runner on the [Actions Settings page](https://github.com/GoogleCloudPlatform/microservices-demo/settings/actions) to authenticate the new runner
6. Start GitHub Actions as a background service:
```
sudo ~/actions-runner/svc.sh install ; sudo ~/actions-runner/svc.sh start
```
