# GROUNDFLOOR Devops Coding Challenge

Infrastructure Coding Test
==========================

# Goal

Script the creation of a web server, and a script to check the server is up.  Please timebox this assessment to no more than 3-4 hours.  If there are portions you are not able to complete in the timeframe, feel free to describe in a file what steps you would take.

# Prerequisites

* You will need an account at an AWS account. Create one if you don't own one already. You can use free-tier resources for this test.
* You will also need a Github account.

# The Task

You are required to set up a new server in AWS. It must:

* Be publicly accessible.
* Run Nginx or your webserver of choice - something to serve up content
* Deploy the content. This can be as simple as a "Hello World", or as complex as a full website. 

You choose. We will not provide the content. 

# Mandatory Work

Fork this repository.

* Utilizing Infrastructure as Code, create the server.
    ok so they want ec2
* Provide instructions (or a deployment pipeline preferably) to deploy the content to the server.
    this makes me think of an ansible playbook that copies a directory to where nginx can read it but will start with just static nginx content for now
* Provide Instructions on deploying the content
    ok setup your terraform and run it
* Provide a script that can be run periodically (and externally) to check if the server is up and serving the expected content (version number or returning a 200 status code). Use your scripting language of choice.
    ok so this will be a little bash script with curl etc, though if I have ansible most days i would use that since it can be prettified more easily by me
* Alter the README to contain the steps required to:
  * Create the server.
  * Deploy the content.
  * Run the checker script.
* Provide us IAM credentials to login to the AWS account. If you have other resources in it make sure we can only access what is related to this test.
* Automate as much as possible.
* Document each step. 
* Make it easy to install

Give us access to your fork, and send us an email when you’re done. Feel free to ask questions if anything is unclear, confusing, or just plain missing.

## Documenting the steps

I am going to deploy an EC2 instance running nginx with a user script or similar to make it say hello Groundfloor. It will be stood up using Terraform. I will also create a super simple curl script that says if I don't get hello Groundfloor to be sad.

If I have time I will use Ansible to do the CM for the EC2 instance and have Terraform further stick the EC2 instance behind an ALB, which I will attach to the EC2, then create an Ansible PB to make sure nginx is running and start it if it isn't.

1. I created the AWS automation user
1. I created the basic Terraform infrastructure
1. I am using [this](https://devops.novalagung.com/terraform-aws-load-balancer-auto-scaling.html) as a starting point to speed up the boilerplate, since IRL I would have something to build on in a Terraform codebase already, or even if we didn't, I would build that first codebase using something like this
1. I'm using the snake_case convention over kebab-case simply because when I double click a resource name in code, snake_case selects the whole word and kebab-case does not
1. One of the starting codeblocks has hardcoded secrets etc. which IRL is a nono, so I'm passing those in dynamically (by cheesing off of [this stack overflow answer](https://stackoverflow.com/a/54557405/11351150) at runtime as environment variables. That can get gross with more than 5 or so variables but for this P.O.C. manually passing them in is fine, IRL we would have some tooling to handle passing in run-time variables in a repeatable less humanly painful manner
1. Another caveat is that this TF will due to time constrains have a local TFstate. If I were to use this long-term I'd create an S3 bucket to hold the tfstate so it's not reliant on my device to work correctly
1. So I got the basic boilerplate out of the way in about 2 hours. Now I am going to need to get nginx installed on the ec2 instance via deploy script so I can also open the firewall ports, give nginx some basic hello groundfloor config etc.
1. Ok so I was doing my first terraform plan that was not giving me syntax issues and I hit the error below
1. So clearly my above step didn't work. So I found [this site](https://medium.com/codex/how-to-use-environment-variables-on-terraform-f2ab6f95f82d) which told me that I still have to define the variables outright in code even if I pass them in as environment variables (which seems obvious in hindsight) and [this other site](https://stackoverflow.com/a/45442490/11351150) which reminded me of the proper variable passing syntax when you are not passing in var files
1. Then I ran into `Error launching source instance: InvalidParameter: Security group sg-0cf88e5ba874f173e and subnet subnet-064075941a6962576 belong to different networks.` when creating the ec2 instance. I fixed that by actually remembering that I need to specify a subnet ID (1a or 1b) for the ec2 instance to 'live in'
1. Then I SSHed into the ec2 instance (with its public IP address turned on) so I could do initial interactive configuration to get the ec2 instance to return hello groundfloor via `ssh ec2-user@<public instance IP> -i ./id_rsa_ec2-nginx`
1. I used [this site](https://www.bswen.com/2022/01/how-to-just-return-a-fixed-string-in-nginx.html) to get my static string code snippet to edit the default nginx config to use
1. Then I baked that into the nginx_ec2_deploy.sh and turned off the public IP address access since that is no longer needed
1. Then I found that while for some reason the ec2 instances do not appear to be running the user_data scripts, I don't have any further time to troubleshoot and fix
1. If I had more time I would figure out why the user_data script is failing, failing to run, or otherwise not doing the contents of nginx_ec2_deploy.sh which work when copy/pastaed into an SSH session
1. The following steps are 'pseudo what i would do next'
1. Then I would figure out a way to involving scp-ing a 'web-content' directory from terraform onto the ec2 instance and configuring nginx to look at it. No having terraform do the configuration management is not ideal, but this is a proof of concept
1. Then I would make an s3 bucket and move my tfstate into that instead of living here locally


## Creating the server
1. Sign in to your AWS account
1. Create an IAM user named automation and give it appropriate permissions (for this proof-of-concept I am just giving AdministratorAccess policy, normally you do least privs, whatever is just enough to CRUD EC2 instances and ALBs and ALB attachments)
1. get the access key and secret key, you will need those later to feed to Terraform
1. make this branch your working copy
1. cd to dmd subdirectory
1. run `terraform init`
1. run `terraform apply -var REG="us-east-1" -var ACC="<key goes here>" -var SEC="<secret goes here>"`
1. note down the returned alb address
1. run `curl -sS <address>` and find that it fails because the ec2 instances are unhealthy due to some reason involving user_data scripts on the instances

## Deploy the content
1. Edit the string on line 29 of nginx_ec2_deploy.sh
1. Rerun the server creation

## Run the checker script
1. run `curl -sS <address>` of whatever the ALB public address is

# Extra Credit

We know time is precious, we won't mark you down for not doing the extra credits, but if you want to give them a go...

* Automate the server setup using Terraform.  Document what is happening in the code.
* Use a configuration management tool (such as Puppet, Chef or Ansible) to bootstrap the server. Document what is happening in your definition files
* Put the server behind a load balancer. Automate this if possible using any tools you are familiar with and document what is going on
* Make the checker script SSH into the instance, check if Nginx is running and start it if it isn't.
* Run Nginx inside a Docker container
* Make it Cloud provider agnostic - i.e. can we repeat this in Azure or Google Cloud Platform

# Questions

#### What scripting languages can I use?

Anyone you like. You’ll have to justify your decision. We use Powershell, nodejs, ReactJS and .Net (amongst others) internally. Please pick something you're familiar with, as you'll need to be able to discuss it.

#### Will I have to pay for the AWS charges?

No. You are expected to use free-tier resources only and not generate any charges. Please remember to delete your resources once the review process is over so you are not charged by AWS.

#### What will you be grading me on?

Scripting skills, elegance, maintainability, understanding of the technologies you use, security, and in case you missed it....documentation!
We don’t want to know if you can do exactly as asked (or everybody would have the same result). We want to know what you bring to the table when working on a project, what is your secret sauce. More features? Best solution? Thinking outside the box?
Hint: we would like to be able to test this outside of the environment you create, so make it reusable

#### Will I have a chance to explain my choices?

Feel free to comment your code, or ideally put explanations in a pull request within the repo in one or more readme files
We’ll discuss the choices you made at a follow up interview.

#### Why doesn't the test include X?

Good question. Feel free to tell us how to make the test better. Or, you know, fork it and improve it!

#### How long should this take?

There are many ways to solve this problem so it may vary for each candidate and depends how far you want to take it but we are confident the basic requirements can be met with 2-3 hours work.
