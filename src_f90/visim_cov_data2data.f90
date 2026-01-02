subroutine cov_data2data(x1, y1, z1, x2, y2, z2, ddcov)
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
!     Returns the covariance between two data points
!     *********************************************
!
! INPUT VARIABLES:
!
!   x1,y1,z1     location of first data point
!   x2,y2,z2     location of second data point
!
! OUTPUT VARIABLES:
!
!   ddcov       data to data covariance
!
! ORIGINAL : Thomas Mejer Hansen                       DATE: October 2004
!
! TODO : Use either lookup table in RAM or a lookup table on disk
!
!-----------------------------------------------------------------------
  use visim_params_mod
  use visim_grid_mod
  use visim_covariance_mod
  implicit none

  ! Arguments
  real, intent(in) :: x1, y1, z1, x2, y2, z2
  real, intent(out) :: ddcov

  ! Local variables
  integer :: i, j, k
  integer :: ix1, iy1, iz1, ix2, iy2, iz2
  integer :: index1, index2
  real :: cov
  logical :: testind

  ! External GSLIB functions
  external :: cova3, getindx

  ! Initialize lookup table (called with x1=0)
  if (x1 == 0) then
    if (idbg > 0) then
      write(*, *) 'Initializing data2data covar lookup table'
    end if
    k = 0
    do i = 1, (nx * ny * nz)
      do j = 1, (nx * ny * nz)
        cd2d(i, j) = UNEST
      end do
    end do
    ddcov = 0
    return
  end if

  ! Calculate the indexes for both data points
  call getindx(nx, xmn, xsiz, x1, ix1, testind)
  call getindx(ny, ymn, ysiz, y1, iy1, testind)
  call getindx(nz, zmn, zsiz, z1, iz1, testind)
  index1 = ix1 + (iy1 - 1) * nx + (iz1 - 1) * nxy

  call getindx(nx, xmn, xsiz, x2, ix2, testind)
  call getindx(ny, ymn, ysiz, y2, iy2, testind)
  call getindx(nz, zmn, zsiz, z2, iz2, testind)
  index2 = ix2 + (iy2 - 1) * nx + (iz2 - 1) * nxy

  ! Check if value is in lookup table
  if (cd2d(index1, index2) == UNEST) then
    ! Calculate the covariance
    call cova3(x1, y1, z1, x2, y2, z2, 1, nst, nst_max, c0, it, &
               cc, aa, 1, nst_max+1, rotmat, cmax, cov)

    ddcov = dble(cov)
    ! Put the value in the lookup table
    cd2d(index1, index2) = ddcov
  else
    ddcov = cd2d(index1, index2)
  end if

  return

end subroutine cov_data2data
