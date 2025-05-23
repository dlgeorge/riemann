! =====================================================
subroutine rp1(maxm,meqn,mwaves,maux,mbc,mx,ql,qr,auxl,auxr,wave,s,amdq,apdq)
! =====================================================

! Riemann solver for the acoustics equations in 1D.

! waves:     2
! equations: 2

! Conserved quantities:
!       1 pressure
!       2 velocity

! On input, ql contains the state vector at the left edge of each cell
!           qr contains the state vector at the right edge of each cell

! On output, wave contains the waves,
!            s the speeds,
! 
!            amdq = A^- Delta q,
!            apdq = A^+ Delta q,
!                   the decomposition of the flux difference
!                       f(qr(i-1)) - f(ql(i))
!                   into leftgoing and rightgoing parts respectively.
! 

! Note that the i'th Riemann problem has left state qr(i-1,:)
!                                    and right state ql(i,:)
! From the basic clawpack routines, this routine is called with ql = qr


    implicit none

    integer, intent(in) :: maxm, meqn, mwaves, mbc, mx, maux
    real(kind=8), intent(in) :: ql(meqn, 1-mbc:maxm+mbc),qr(meqn, 1-mbc:maxm+mbc)

    real(kind=8), intent(out)  :: wave(meqn, mwaves, 1-mbc:maxm+mbc)
    real(kind=8), intent(out) :: s(mwaves,1-mbc:maxm+mbc)
    real(kind=8), intent(out) :: apdq(meqn, 1-mbc:maxm+mbc), amdq(meqn, 1-mbc:maxm+mbc)

    real(kind=8) :: delta(2)
    real(kind=8) :: rho, bulk, cc, zz
    real(kind=8) :: a1, a2, auxl, auxr
    integer :: i, m

    ! density, bulk modulus, and sound speed, and impedence of medium:
    ! (should be set in setprob.f)
    common /cparam/ rho,bulk,cc,zz

!     # split the jump in q at each interface into waves

!     # find a1 and a2, the coefficients of the 2 eigenvectors:
    do 20 i = 2-mbc, mx+mbc
        delta(1) = ql(1,i) - qr(1,i-1)
        delta(2) = ql(2,i) - qr(2,i-1)
        a1 = (-delta(1) + zz*delta(2)) / (2.d0*zz)
        a2 =  (delta(1) + zz*delta(2)) / (2.d0*zz)
    
    !        # Compute the waves.
    
        wave(1,1,i) = -a1*zz
        wave(2,1,i) = a1
        s(1,i) = -cc
    
        wave(1,2,i) = a2*zz
        wave(2,2,i) = a2
        s(2,i) = cc
    
    20 END DO


!     # compute the leftgoing and rightgoing flux differences:
!     # Note s(1,i) < 0   and   s(2,i) > 0.

    do m=1,meqn
        do i = 2-mbc, mx+mbc
            amdq(m,i) = s(1,i)*wave(m,1,i)
            apdq(m,i) = s(2,i)*wave(m,2,i)
        end do
    end do

    return
    end subroutine rp1
