subroutine cov_data2vol(index, x1, y1, z1, ivol, vvcov)
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
!     Returns the covariance between a data point and a volume
!     in case volume average data is present
!     *********************************************
!
! INPUT VARIABLES:
!
!   index        index of data point considered
!   x1,y1,z1     location of data point
!   ivol         volume number
!
! OUTPUT VARIABLES:
!
!   vvcov       data to volume covariance
!
! ORIGINAL : Thomas Mejer Hansen                       DATE: June 2004
!
! TODO : Use either lookup table in RAM or a lookup table on disk
!
!-----------------------------------------------------------------------
  use visim_params_mod
  use visim_grid_mod
  use visim_volume_mod
  use visim_covariance_mod
  implicit none

  ! Arguments
  integer, intent(in) :: index, ivol
  real, intent(in) :: x1, y1, z1
  real, intent(out) :: vvcov

  ! Local variables
  real :: ddcov, covsum
  integer :: i, j, k, ivol_temp, ix, iy, iz
  real :: x2, cov

  ! External GSLIB functions
  external :: cova3

  if (ivol == 0) then
    if (idbg > 0) then
      write(*, *) 'Initializing data2vol covar lookup table'
    end if
    k = 0
    do i = 1, (nx * ny * nz)
      do j = 1, maxvols_dim
        cd2v(i, j) = UNEST
      end do
    end do
    vvcov = 0
    return
  end if

  ! UNCOMMENT NEXT LINE TO NOT USE LOOKUP TABLE
  ! cd2v(index,ivol) = UNEST

  if (cd2v(index, ivol) == UNEST) then
    ! CALCULATE THE VALUE
    covsum = 0
    do i = 1, ndatainvol(ivol)
      call cova3(volx(ivol, i), voly(ivol, i), volz(ivol, i), &
                 x1, y1, z1, 1, nst, nst_max, c0, it, &
                 cc, aa, 1, nst_max+1, rotmat, cmax, cov)

      covsum = voll(ivol, i) * dble(cov) + covsum
    end do

    vvcov = covsum
    ! put the value in the lookup table
    ! comment this line out to disable the lookup table
    ! in this case the cd2v variable should be removed from the visim.inc file
    cd2v(index, ivol) = vvcov
  else
    vvcov = cd2v(index, ivol)
  end if

  return

end subroutine cov_data2vol
