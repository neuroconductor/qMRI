qflashmr1 <- function(par,design){
  n <- dim(design)[1]
  z<-.Fortran("qflashm1",
              as.double(par),
              as.double(design),
              as.integer(n),
              fval=double(n),
              grad=double(4*n),
              PACKAGE="qMRI")[c("fval","grad")]
  fval <- z$fval
  attr(fval,"gradient") <- matrix(z$grad,n,4)
  fval
}

qflashmr0 <- function(par,design){
  n <- dim(design)[1]
  fval <- .Fortran("qflashm0",
              as.double(par),
              as.double(t(design)),
              as.integer(n),
              fval=double(n),
              PACKAGE="qMRI")$fval
  fval
}

qflashpl <- function(par,design){
#
#  partial linear model
#
  n <- dim(design)[1]
  z <- .Fortran("qflashpl",
                   as.double(par),
                   as.double(design),
                   as.integer(n),
                   fval=double(n),
                   grad=double(4*n),
                   PACKAGE="qMRI")[c("fval","grad")]
  fval <- z$fval
  attr(fval,"gradient") <- matrix(z$grad,n,4)
  fval
}

qflashpl2 <- function(par, design){
  #
  #  partial linear model without MT
  #
  n <- dim(design)[1]
  z <- .Fortran("qflashpl2",
                as.double(par),
                as.double(design),
                as.integer(n),
                fval = double(n),
                grad = double(3*n),
                PACKAGE = "qMRI")[c("fval", "grad")]
  fval <- z$fval
  attr(fval, "gradient") <- matrix(z$grad, n, 3)
  fval
}


reparamtrizeconstTR <- function(th,a1,a2,TR){
#
#   Parameter transformation for constant TR
#   from    S_T1(TE,alpha) = th[1] exp(-R2 TE)
#           S_MT(TE,alpha) = th[2] exp(-R2 TE)
#           S_PD(TE,alpha) = th[3] exp(-R2 TE)
#      parameters th 
#   to      S_T1(TE,alpha) = p[1] exp(-R2 TE) sin(a1) (1-exp(-TR p[2]))/(1-cos(a1) exp(-TR p[2])) 
#           S_MT(TE,alpha) = p[1] exp(-R2 TE) p[3] sin(a2) (1-exp(-TR p[2]))/(1-cos(a1) exp(-TR p[2])) 
#           S_PD(TE,alpha) = p[1] exp(-R2 TE) sin(a2) (1-exp(-TR p[2]))/(1-cos(a2) exp(-TR p[2])) 
#      parameters  p
#
   sa1th3 <- sin(a1)*th[3]
   sa2th1 <- sin(a2)*th[1]
   ca1 <- cos(a1)
   ca2 <- cos(a2)
   emTRR1 <- (sa2th3-sa1th1)/(ca1*sa2th3-ca2*sa1th1)
   R1 <-   -log(emTRR1)/TR
   S0 <- th[1]/sin(a1)*(1-ca1*emTRR1)/(1-emTRR1)
   M <- th[2]/th[3]
}

R1conf <- function(theta,si2,aT1,aPD,TR=1,alpha=0.05){
    ##
    ##   construct confidence region for parameter E1 
    ##   parameters are expected to be named as "ST1", "SPD" and "R2star", 
    ##          parameter "SMT" is not used
    ##
    fc1 <- sin(aT1)/sin(aPD)
    fc2 <- cos(aT1)
    fc3 <- fc1*cos(aPD)
    th <- theta[c("ST1","SPD")]
    E1 <- (th[1]-th[2]*fc1)/(th[1]*fc2-th[2]*fc3)
    R1 <- -log(E1)/TR
    if(any(theta==0)){
    ## no interior solution, unable to provide confidence regions
       return(list(E1=E1,CIE1=c(NA,NA),R1=R1,CIR1=c(NA,NA)))
       }
    th <- theta[c("ST1","SPD")]
    Amat <- si2[c("ST1","SPD"),c("ST1","SPD")][c(1,2,4)]
#    qnsq <- qnorm(1-alpha/2)^2
    qnsq <- qchisq(1-alpha,2)    
    th2ofth1 <- function(th1,th,Amat,qnsq){
        th1diff <- (th1-th[1])
        p <- th[2]- th1diff*Amat[2]/Amat[3]
        q <- (qnsq - th1diff^2*Amat[1]+2*th1diff*th[2]*Amat[2])/Amat[3]-th[2]^2
        D <- p^2+q
        th2 <- if(D>=0) c(p-sqrt(D),p+sqrt(D)) else c(NA,NA)
        th2
    }
    
    ## now search for min/max of (1-fc1*th2(th1)/th1)/(fc2-fc3*th2(th1)/th1)
    e1 <- th[2]+th[1]*Amat[2]/Amat[3]
    e2 <- qnsq/Amat[3]
    e3 <- (Amat[1]*Amat[3]-Amat[2]^2)/Amat[3]^2
    e4 <- th[1]
    e0 <- e3^2*e4^2+e1^2*e3
    q <- (e3^2*e4^4+e2^2-2*e3*e4^2*e2-e1^2*e2+e1^2*e3*e4^2)/e0
    p <- -(e2*e3*e4-e3^2*e4^3-e1^2*e3*e4)/e0
    D <- p^2-q
    th1 <- if(D>=0) c(p-sqrt(D),p+sqrt(D)) else c(NA,NA)
    th2 <- th2ofth1(th1[2],th,Amat,qnsq)
    CIE1 <- (th1-th2*fc1)/(th1*fc2-th2*fc3)
    CIR1 <- -log(CIE1)/TR
    list(E1=E1,CIE1=sort(CIE1),R1=R1,CIR1=sort(CIR1))
   }
   
   