# variable for webapp image name
variable "webapp_image" {
  default = "etahamad/apsnet-mssql:0.0.1"
}

# Create security group for load balancer
resource "aws_security_group" "lb" {
  name        = "lb"
  description = "Allow incoming HTTP traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow HTTP"
  }
}

# Create security group for web servers
resource "aws_security_group" "web" {
  name        = "web"
  description = "Allow traffic from load balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from load balancer"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.lb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow HTTP from LB"
  }
}

# Create security group for Redis
resource "aws_security_group" "redis" {
  name        = "redis"
  description = "Allow traffic from web servers"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Redis from web servers"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow Redis from web servers"
  }
}

# Create security group for MongoDB 
resource "aws_security_group" "mongo" {
  name        = "mongo"
  description = "Allow traffic from web servers"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MongoDB from web servers"
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow MongoDb from web servers"
  }
}

# Create security group for SQL Server
resource "aws_security_group" "sql" {
  name        = "sql"
  description = "Allow traffic from web servers"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "SQL Server from web servers"
    from_port       = 1433
    to_port         = 1433
    protocol        = "tcp"
    security_groups = [aws_security_group.web.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Allow SQL Server from web servers"
  }
}

# Create Kubernetes deployment and service for web app
resource "kubernetes_deployment" "webapp" {
  metadata {
    name = "webapp"
    labels = {
      app = "webapp"
    }
  }

  spec {
    replicas = 3

    selector {
      match_labels = {
        app = "webapp"
      }
    }

    template {
      metadata {
        labels = {
          app = "webapp"
        }
      }

      spec {
        container {
          image = var.webapp_image
          name  = "webapp"

          port {
            container_port = 80
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "webapp" {
  metadata {
    name = "webapp"
  }
  spec {
    selector = {
      app = kubernetes_deployment.webapp.spec.0.template.0.metadata[0].labels.app
    }
    port {
      port        = 80
      target_port = 80
    }
    type = "NodePort"
  }
}

variable "eks_cluster_name" {
  default = "demo"
}

# Create Kubernetes deployments and services for databases
resource "kubernetes_deployment" "mongodb" {
  metadata {
    name = "mongodb"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "mongodb"
      }
    }

    template {
      metadata {
        labels = {
          app = "mongodb"
        }
      }

      spec {
        container {
          image = "mongo"
          name  = "mongodb"

          port {
            container_port = 27017
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "mongodb" {
  metadata {
    name = "mongodb"
  }
  spec {
    selector = {
      app = kubernetes_deployment.mongodb.spec.0.template.0.metadata[0].labels.app
    }
    port {
      port        = 27017
      target_port = 27017
    }
  }
}

resource "kubernetes_deployment" "redis" {
  metadata {
    name = "redis"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "redis"
      }
    }

    template {
      metadata {
        labels = {
          app = "redis"
        }
      }

      spec {
        container {
          image = "redis"
          name  = "redis"

          port {
            container_port = 6379
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "redis" {
  metadata {
    name = "redis"
  }

  spec {
    selector = {
      app = kubernetes_deployment.redis.spec.0.template.0.metadata[0].labels.app
    }

    port {
      port        = 6379
      target_port = 6379
    }
  }
}
# Kubernetes deployment and service for SQL Server
resource "kubernetes_deployment" "sqlserver" {
  metadata {
    name = "sqlserver"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "sqlserver"
      }
    }

    template {
      metadata {
        labels = {
          app = "sqlserver"
        }
      }

      spec {
        container {
          image = "mcr.microsoft.com/azure-sql-edge:1.0.4"
          name  = "sqlserver"

          port {
            container_port = 1433
          }

          env {
            name  = "ACCEPT_EULA"
            value = "Y"
          }

          env {
            name  = "SA_PASSWORD"
            value = "example_123"
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "sqlserver" {
  metadata {
    name = "sqlserver"
  }

  spec {
    selector = {
      app = kubernetes_deployment.sqlserver.spec.0.template.0.metadata[0].labels.app
    }

    port {
      port        = 1433
      target_port = 1433
    }
  }
}

# Create load balancer
resource "aws_lb" "webapp" {
  name               = "webapp-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id]
  subnets            = [aws_subnet.public-us-east-1a.id, aws_subnet.public-us-east-1b.id]
}


resource "aws_lb_target_group" "webapp" {
  name     = "webapp-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id
}

resource "aws_lb_target_group_attachment" "webapp" {
  target_group_arn = aws_lb_target_group.webapp.arn
  target_id        = kubernetes_service.webapp.status.0.load_balancer.0.ingress.0.hostname
  port             = 80
}

resource "aws_lb_listener" "webapp" {
  load_balancer_arn = aws_lb.webapp.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webapp.arn
  }
}

# Get SSL certificate from ACM
data "aws_acm_certificate" "cert" {
  domain = var.domain_name
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.webapp.arn
  port              = "443"
  protocol          = "HTTPS"
  certificate_arn   = data.aws_acm_certificate.cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webapp.arn
  }
}

# Configure DNS
resource "aws_route53_record" "webapp" {
  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.webapp.dns_name
    zone_id                = aws_lb.webapp.zone_id
    evaluate_target_health = true
  }
}