! =====================================================================
subroutine rp1(maxmx,meqn,mwaves,maux,mbc,mx,ql,qr,auxl,auxr,fwave,s,amdq,apdq)
! =====================================================================
!
!solve Riemann problems for the 1D shallow water equations
!    with source-term resulting from variable topography b(x,t)
!    (h)_t + (u h)_x = 0
!    (uh)_t + (uuh + 0.5*gh**2)_x = -g*h*b_x
!
!
!
!     On input,
!     ql contains the state vector at the left edge of each cell
!     qr contains the state vector at the right edge of each cell
!
!     On output, wave contains the fwaves/s,
!                s the speeds,
!                amdq the  left-going flux difference  A**- \Delta q
!               apdq the right-going flux difference  A**+ \Delta q
!
!     Note that the i'th Riemann problem has left state qr(i-1,:)
!     #                                    and right state ql(i,:)
!     From the basic clawpack routine step1, rp1 is called with ql=qr=q.
!
!      This is for use with the Riemann solver(s) used in GeoClaw
!        but for 1D problems. That is, it calls the same solver for left and
!        right states that is used for 2d problems.
!
!        This routine deals with dry-state problems over topography
!        by testing a wall boundary condition, like that done in GeoClaw 2d
!
!        to call other point-wise Riemann solvers alter the call on line 177


    implicit none

    ! Input arguments
    integer, intent(in) :: maxmx,meqn,mwaves,mbc,mx,maux

    double precision, intent(in), dimension(meqn, 1-mbc:maxmx+mbc) :: ql,qr
    double precision, intent(in), dimension(maux, 1-mbc:maxmx+mbc) :: auxl,auxr

    ! Output arguments
    double precision, intent(out) :: s(mwaves, 1-mbc:maxmx+mbc)
    double precision, intent(out) :: fwave(meqn, mwaves, 1-mbc:maxmx+mbc)
    double precision, intent(out), dimension(meqn, 1-mbc:maxmx+mbc) :: amdq,apdq

    !Local
    integer :: m,i,mw,maxiter
    double precision :: drytol,g
    double precision :: hR,hL,huR,huL,uR,uL,hvR,hvL,vR,vL,phiR,phiL
    double precision :: bR,bL,sL,sR,sRoe1,sRoe2,sE1,sE2,uhat,chat
    double precision :: hstartest,hstarHLL,sLtest,sRtest
    double precision :: wall(2), fw(3,3)

    !Common blocks
    double precision :: grav,drytolerance

    common /geo/ grav,drytolerance

    g=grav
    drytol=drytolerance

    !loop through Riemann problems at each grid cell
      do i=2-mbc,mx+mbc

!-----------------------Initializing-----------------------------------
         !inform of a bad riemann problem from the start
         if((qr(i-1,1).lt.0.d0).or.(ql(i,1) .lt. 0.d0)) then
            write(*,*) 'Negative input: hl,hr,i=',qr(i-1,1),ql(i,1),i
         endif

         !Initialize Riemann problem for grid interface
         do mw=1,mwaves
              s(i,mw)=0.d0
              do m=1,meqn
                 fwave(i,m,mw)=0.d0
              enddo
         enddo

         !zero (small) negative values if they exist
         if (qr(i-1,1).lt.0.d0) then
            qr(i-1,1)=0.d0
            qr(i-1,2)=0.d0
         endif

         if (ql(i,1).lt.0.d0) then
            ql(i,1)=0.d0
            ql(i,2)=0.d0
         endif

         !skip problem if in a completely dry area
         if (qr(i-1,1).le.drytol.and.ql(i,1).le.drytol) then
            go to 30
         endif

         !Riemann problem variables
         hL = qr(i-1,1)
         hR = ql(i,1)
         huL = qr(i-1,2)
         huR = ql(i,2)
         bL = auxr(i-1,1)
         bR = auxl(i,1)

         hvL=0.d0
         hvR=0.d0

         !check for wet/dry boundary
         sE1= 1.d99
         sE2=-1.d99
         wall(2) = 1.d0
         wall(1) = 1.d0
         if (hR.le.drytol) then
            sLtest=min(-sqrt(g*hL),huL/hL-sqrt(g*hL)) !what would be the Einfeldt speed of wall problem
            hstartest=hL-(huL/sLtest) !what would be middle state in approx Riemann solution
            if (hstartest+bL.lt.bR) then !right state should become ghost values that mirror left for wall problem
               wall(2)=0.d0
               hR=hL
               huR=-huL
               bR=bL
               phiR=phiL
            endif
         elseif (hL.le.drytol) then ! right surface is lower than left topo
            sRtest=max(sqrt(g*hR),huR/hR+sqrt(g*hR)) !what would be the Einfeldt speed of wall
            hstartest= hR-(huR/sRtest) !what would be middle state in approx Rimeann solution
            if (hstartest+bR.lt.bL) then  !left state should become ghost values that mirror right
               wall(1)=0.d0
               hL=hR
               huL=-huR
               bL=bR
               phiL=phiR
            endif
         endif

         if (hR.gt.drytol) then
            uR=huR/hR
            vR=hvR/hR
            phiR = 0.5d0*g*hR**2 + huR**2/hR
         else
            hR = 0.d0
            huR = 0.d0
            uR = 0.d0
            vR = 0.d0
            phiR = 0.d0
            sE2 = max(sE2,huL/hL+2.d0*sqrt(g*hL))
         endif

         if (hL.gt.drytol) then
            uL=huL/hL
            vL=hvL/hL
            phiL = 0.5d0*g*hL**2 + huL**2/hL
         else
            hL=0.d0
            huL=0.d0
            uL=0.d0
            vL=0.d0
            phiL = 0.d0
            sE1 = min(sE1,huR/hR - 2.d0*sqrt(g*hR))
         endif

         !determine wave speeds
         sL=uL-sqrt(g*hL) ! 1 wave speed of left state
         sR=uR+sqrt(g*hR) ! 2 wave speed of right state

         uhat=(sqrt(g*hL)*uL + sqrt(g*hR)*uR)/(sqrt(g*hR)+sqrt(g*hL)) ! Roe average
         chat=sqrt(g*0.5d0*(hR+hL)) ! Roe average
         sRoe1=uhat-chat ! Roe wave speed 1 wave
         sRoe2=uhat+chat ! Roe wave speed 2 wave

         sE1 = min(sE1,min(sL,sRoe1)) ! Eindfeldt speed 1 wave
         sE2 = max(sE2,max(sR,sRoe2)) ! Eindfeldt speed 2 wave

         !--------------------end initializing...finally----------
         !solve Riemann problem.

         maxiter = 1

         call riemann_ssqfwave(maxiter,meqn+1,mwaves+1,hL,hR,huL,huR, &
         &  hvL,hvR,bL,bR,uL,uR,vL,vR,phiL,phiR,sE1,sE2,drytol,g,fw)

!         call riemann_fwave(meqn+1,mwaves+1,hL,hR,huL,huR,hvL,hvR, &
!           &   bL,bR,uL,uR,vL,vR,phiL,phiR,sE1,sE2,drytol,g,fw)

         s(i,1) = sE1*wall(1)
         s(i,2) = sE2*wall(2)

         do m=1,meqn
            fwave(i,m,1)=fw(m,1)*wall(1)
            fwave(i,m,2)=fw(m,3)*wall(2)
         enddo


 30      continue
      enddo


      do i=2-mbc,mx+mbc
         do m=1,meqn
            amdq(i,m) = 0.d0
            apdq(i,m) = 0.d0
            do  mw=1,mwaves
               if (s(i,mw).lt.0.d0) then
                  amdq(i,m) = amdq(i,m) + fwave(i,m,mw)
               elseif (s(i,mw).gt.0.d0) then
                  apdq(i,m) = apdq(i,m) + fwave(i,m,mw)
               else
                  amdq(i,m) = amdq(i,m) + .5d0*fwave(i,m,mw)
                  apdq(i,m) = apdq(i,m) + .5d0*fwave(i,m,mw)
               endif
            enddo
         enddo
      enddo

      return
      end subroutine rp1
