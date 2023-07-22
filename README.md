# Widebot DevOps task

This project uses Terraform, Kubernetes, and Github Actions to deploy a ASP.NET application on AWS EKS using CI/CD. Here is how you can set it up:

## Prerequisites

Before you begin, you will need to have the following:

- Docker installed on out machine.
- Terraform installed on out machine.
- kubectl installed on out machine.
- AWS CLI installed and configured on out machine.
- Base64 tool for encoding files.
- An AWS account.
- A GitHub account.
- Domain (I used domain linked to cloudflare)

## Directory Structure

- `app/`: This directory contains the ASP.net application and the Dockerfile.
- `terraform/`: This directory contains the Terraform configuration files to build EKS and ECR on AWS.
- `k8s/`: This directory contains Kubernetes manifest files to deploy the Go application along with the database.
- `.github/workflows/`: This directory contains the GitHub Actions CI/CD workflow configurations.

## Setup Steps

### Step 1: AWS Setup

Firstly, make sure you have configured out AWS CLI with the appropriate AWS account credentials.

```bash
aws configure
```

### Step 2: Terraform Setup

Navigate to the `terraform/` directory and initialize Terraform:

```bash
cd terraform
terraform init
```

Plan the Terraform changes:

```bash
terraform plan
```

If everything looks good, apply the changes (this takes 20m):

```bash
terraform apply --auto-approve
```

### Step 3: Kubernetes Setup

After EKS is set up, you should configure kubectl to interact with the EKS cluster

```
aws eks update-kubeconfig --name <CLUSTER_NAME> --region <REGION>
```

Incase of our clutster we will use:
```
aws eks update-kubeconfig --name demo --region <REGION> --kubeconfig <FILE_NAME>
```

Then ou can get the kubeconfig file by following the instructions provided by AWS (We will use it later for CI/CD).
```
aws eks update-kubeconfig --name demo --region us-east-1 --kubeconfig kubeconfig
```

After you have out kubeconfig file, encode it in base64:

```bash
base64 /path/to/out/kubeconfig > kubeconfig64
```

### Step 4: GitHub Secrets Setup

Navigate to out GitHub repository and go to "Settings" -> "Secrets and variables" -> "Actions ". Here you need to add the following secrets:

- `AWS_ACCESS_KEY_ID`: The AWS access key ID for out account.
- `AWS_SECRET_ACCESS_KEY`: The AWS secret access key for out account.
- `KUBECONFIG`: The base64 encoded kubeconfig file from step 3 (kubeconfig64).

### Step 5: CI/CD Setup

GitHub Actions is used for continuous integration and deployment. The workflows are automatically triggered when a push or pull request is made to the main branch. The `ci.yml` workflow builds the Docker image and pushes it to ECR. The `cd.yml` workflow deploys the application to the EKS cluster using the Kubernetes manifests.

`NOTE:` Make sure to update the `Image` from the `k8s/aspnet-app-deployment.yaml` file with the `ECR_URI` from out `AWS` or docker image.

## Running the Application

After completing the setup, you can make changes to the Go application in the `app/` directory and push out changes. GitHub Actions will automatically build, push, and deploy out changes.

Make sure to check the "Actions" tab in out GitHub repository to see the status of out workflows.

## Cleanup

To clean up out AWS resources, navigate to the `terraform/` directory and destroy the Terraform resources (this takes 20m):

```bash
terraform destroy --auto-approve
```

## SSL, Domain
To add a domain name with a valid SSL certificate and set up a LoadBalancer to distribute traffic across instances of the web application, you'll need to perform the following steps:

Step 1: Obtain a valid SSL certificate

You need to obtain an SSL certificate from a trusted Certificate Authority (CA) for out domain. I used AWS Certificate, you can google how to get aws cert and verify it using AWS.

Step 2: Update the ASP.NET Core Web Application Service to use SSL

Update the `aspnet-app-deployment.yaml` file to use the SSL certificate:

```
alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:us-east-1:362884572950:certificate/7a643a73-91b3-4627-b7b7-bb48403e4d46
```

Step 3: Update the Deployment to use the correct ports

Step 4: Update the Hosting Configuration in the app:
In out `Configure` method in `Startup.cs`, update the hosting configuration to handle HTTPS traffic on port 443. You can do this using the `UseHttpsRedirection` middleware:

```
    // Enable HTTPS redirection
    app.UseHttpsRedirection();
```

Step 5: Apply the updated manifests

Apply the updated Deployment and Service YAML files:

Step 6: Expose Kubernetes Service to the domain:
Run the following command to get the details of your Kubernetes Service:

```bash
kubectl get svc -n aspnet-app
```
Look for the Service with the appropriate name that corresponds to your web app.
Note down the external IP or hostname of the Service. This IP/hostname is what you'll use for the CNAME record in Cloudflare.

Then update Cloudflare DNS Record:
Now that you have obtained the external IP or hostname of your Kubernetes Service, you can update the existing CNAME record in Cloudflare's DNS settings.

In Cloudflare, navigate to your domain's DNS settings, and find the CNAME record you previously added (e.g., "app").
Update the "Target" field with the new external IP or hostname of your Kubernetes Service.
The updated CNAME record should look like this:

| Type  | Name      | Content                         | TTL  | Status |
|-------|-----------|---------------------------------|------|--------|
| CNAME | app       | your-kubernetes-svc-hostname    | Auto | DNS Only |

Now, the ASP.NET Core web application will be accessible over HTTPS at out configured domain name (`https://app.domain.com`). The LoadBalancer will distribute traffic across instances of the web application, providing a scalable and highly available setup. The SSL certificate ensures secure communication between clients and the web application.


## integrate redis to the app
To integrate a Redis caching layer into the ASP.NET Core web application for improved performance, you'll need to make modifications to the application code and add a Redis container to out Kubernetes deployment. Here's how you can do it:

Step 1: Update the ASP.NET Core web application code

In out ASP.NET Core web application code, you'll need to use a caching library to interact with the Redis cache. For this example, we'll use the `StackExchange.Redis` library, which is a popular choice for .NET applications.

First, install the `StackExchange.Redis` NuGet package in out ASP.NET Core project:

```bash
dotnet add package StackExchange.Redis
```

Create a Service Class:
First, you need to create a new service class in out ASP.NET Core project. This service class will encapsulate the logic for data retrieval using Redis caching. You can create a new file named MyService.cs or any other meaningful name for out service.

Implement the Code:
In the `MyService.cs` file, add the code:

```csharp
using Microsoft.Extensions.Caching.Distributed;
using System;
using System.Threading.Tasks;

public class MyService
{
    private readonly IDistributedCache _cache;

    public MyService(IDistributedCache cache)
    {
        _cache = cache;
    }

    public async Task<string> GetDataFromCacheOrDatabaseAsync(string key)
    {
        // Try to get the data from the cache
        var cachedData = await _cache.GetStringAsync(key);

        if (cachedData != null)
        {
            return cachedData;
        }
        else
        {
            // If data is not in the cache, retrieve it from the database
            var data = await GetDataFromDatabaseAsync();

            // Store the data in the cache with an expiration time (e.g., 5 minutes)
            var cacheOptions = new DistributedCacheEntryOptions
            {
                AbsoluteExpirationRelativeToNow = TimeSpan.FromMinutes(5)
            };

            await _cache.SetStringAsync(key, data, cacheOptions);

            return data;
        }
    }

    private async Task<string> GetDataFromDatabaseAsync()
    {
        // Simulate a call to the database (replace with out actual database logic)
        await Task.Delay(100); // Simulate a 100ms delay
        return "Data from the database";
    }
}

```
Register the Service:
After creating the MyService class, you need to register it with the ASP.NET Core dependency injection container in the ConfigureServices method of out Startup.cs file.
Open out `Startup.cs` file, and in the `ConfigureServices` method, add the following line to register `MyService` as a transient service:

```
using Microsoft.Extensions.DependencyInjection;

public class Startup
{
    // ... other code ...

    public void ConfigureServices(IServiceCollection services)
    {
        // ... other services ...

        services.AddControllersWithViews();

        // Register MyService as a transient service
        services.AddTransient<MyService>();
    }

    // ... other code ...
}
```
Use the Service in Controllers or Other Services:
Now that you have registered the `MyService` class as a transient service, you can use it in out controllers or other services by injecting it through the constructor. For example, in our controller:

```
using Microsoft.AspNetCore.Mvc;

public class MyController : Controller
{
    private readonly MyService _myService;

    public MyController(MyService myService)
    {
        _myService = myService;
    }

    public async Task<IActionResult> MyAction()
    {
        var key = "my_data_key";
        var data = await _myService.GetDataFromCacheOrDatabaseAsync(key);
        return View(data);
    }
}
```

Step 2: Update the Kubernetes deployment manifest

Add the Redis container to out Kubernetes deployment manifest (`aspnet-app-deployment.yaml`). Also, ensure out ASP.NET Core application can connect to the Redis container using Kubernetes service DNS.


Step 3: Update the ASP.NET Core web application Service

Ensure the ASP.NET Core web application can access the Redis container by updating the service to expose the Redis container's port (6379) within the Kubernetes cluster.



Step 4: Deploy the Redis container and updated ASP.NET Core web application

Apply the updated manifests to deploy the Redis container and the ASP.NET Core web application:


With these changes, out ASP.NET Core web application will now use Redis as a caching layer, which can significantly improve the application's performance by reducing the need to access the database frequently for certain data. Redis caching helps store and retrieve data quickly, resulting in faster response times for out application.

## AWS Diagram
![diagram](https://github.com/etahamad/widebot-devops-task/assets/53538887/0a4e3c1e-52b7-4345-b2be-57f25a770f14)
