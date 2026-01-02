subroutine cov_vol2vol(ivol1, ivol2, vvcov)
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!                                                                      %
! Copyright (C) 1996, The Board of Trustees of the Leland Stanford    %
! Junior University.  All rights reserved.                            %
!                                                                      %
! Converted to Fortran 90 - 2026                                      %
!                                                                      %
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!-----------------------------------------------------------------------
!
!     Returns the covariance between two volumes, ivol1 and ivol2
!     in case volume average data is present
!     *********************************************
!
! INPUT VARIABLES:
!
!   ivol1        number of volume 1
!   ivol2        number of volume 2
!
! OUTPUT VARIABLES:
!
!   vvcov       volume to volume covariance
!
! ORIGINAL : Thomas Mejer Hansen                       DATE: June 2004
!
! TODO : Use either lookup table in RAM or a lookup table on disk
!
!-----------------------------------------------------------------------
  use visim_params_mod
  use visim_volume_mod
  use visim_covariance_mod
  implicit none

  ! Arguments
  integer, intent(in) :: ivol1, ivol2
  real, intent(out) :: vvcov

  ! Local variables
  integer :: i, j, k, ivol_temp
  real :: x1, x2, y1, y2, z1, z2
  real :: cov

  ! External GSLIB functions
  external :: cova3

  if ((ivol1 == 0) .and. (ivol2 == 0)) then
    if (idbg > 0) then
      write(*, *) 'Initializing vol2vol covar lookup table'
    end if
    k = 0
    do i = 1, maxvols_dim
      do j = 1, maxvols_dim
        cv2v(i, j) = UNEST
      end do
    end do
    vvcov = 0
    return
  end if

  ! UNCOMMENT NEXT LINE TO NOT USE LOOKUP TABLE
  ! cv2v(ivol1,ivol2) = UNEST

  if (cv2v(ivol1, ivol2) == UNEST) then
    vvcov = 0
    do i = 1, ndatainvol(ivol1)
      do j = 1, ndatainvol(ivol2)
        x1 = volx(ivol1, i)
        y1 = voly(ivol1, i)
        z1 = volz(ivol1, i)
        x2 = volx(ivol2, j)
        y2 = voly(ivol2, j)
        z2 = volz(ivol2, j)

        call cova3(x1, y1, z1, &
                   x2, y2, z2, 1, nst, nst_max, c0, it, &
                   cc, aa, 1, nst_max+1, rotmat, cmax, cov)

        vvcov = vvcov + dble(cov) * (voll(ivol1, i) * voll(ivol2, j))
      end do
    end do
    ! PUT VALUE IN LOOKUP TABLE
    cv2v(ivol1, ivol2) = dble(vvcov)
  else
    vvcov = dble(cv2v(ivol1, ivol2))
  end if

  return

end subroutine cov_vol2vol
