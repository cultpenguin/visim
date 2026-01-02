subroutine ctable
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
!               Establish the Covariance Look up Table
!               **************************************
!
! The idea is to establish a 3-D network that contains the covariance
! value for a range of grid node offsets that should be at as large
! as twice the search radius in each direction.  The reason it has to
! be twice as large as the search radius is because we want to use it
! to compute the data covariance matrix as well as the data-point
! covariance matrix.
!
! Secondly, we want to establish a search for nearby nodes that
! in order of closeness as defined by the variogram.
!
!
!
! INPUT VARIABLES:
!
!   xsiz,ysiz,zsiz  Definition of the grid being considered
!   maxctx_dim,maxcty_dim,maxctz_dim  Number of blocks in covariance table
!
!   covariance table parameters
!
!
!
! OUTPUT VARIABLES:  covtab()         Covariance table
!
! EXTERNAL REFERENCES:
!
!   sqdist          Computes 3-D anisotropic squared distance
!   sortem          Sorts multiple arrays in ascending order
!   cova3           Computes the covariance according to a 3-D model
!
!
!
!-----------------------------------------------------------------------
  use visim_params_mod
  use visim_grid_mod
  use visim_covariance_mod
  use visim_search_mod
  implicit none

  ! Local variables
  real, parameter :: TINY = 1.0e-10
  real*8 :: hsqd, sqdist
  logical :: first
  integer :: i, j, k, ic, jc, kc, il, loc, ix, iy, iz
  integer :: maxcxy
  real :: xx, yy, zz
  integer :: c, d, e, f, g, h  ! Dummy variables for sortem

  ! External GSLIB functions
  external :: cova3, sqdist, sortem

  ! Size of the look-up table:
  nctx = min(((maxctx_dim - 1) / 2), (nx - 1))
  ncty = min(((maxcty_dim - 1) / 2), (ny - 1))
  nctz = min(((maxctz_dim - 1) / 2), (nz - 1))

  ! Debugging output:
  if (idbg > -2) then
    write(ldbg, *)
    write(ldbg, *) 'Covariance Look up table and search for previously'
    write(ldbg, *) 'simulated grid nodes.  The maximum range in each '
    write(ldbg, *) 'coordinate direction for covariance look up is:'
    write(ldbg, *) '          X direction: ', nctx * xsiz
    write(ldbg, *) '          Y direction: ', ncty * ysiz
    write(ldbg, *) '          Z direction: ', nctz * zsiz
    write(ldbg, *) 'Node Values are not searched beyond this distance!'
    write(ldbg, *)
  end if

  ! NOTE: If dynamically allocating memory, and if there is no shortage
  !       it would a good idea to go at least as far as the radius and
  !       twice that far if you wanted to be sure that all covariances
  !       in the left hand covariance matrix are within the table look-up.
  !
  ! Initialize the covariance subroutine and cbb at the same time:
  !
  call cova3(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1, nst, nst_max, c0, it, cc, aa, &
             1, nst_max+1, rotmat, cmax, cbb)

  ! Now, set up the table and keep track of the node offsets that are
  ! within the search radius:

  nlooku = 0
  maxcxy = maxctx_dim * maxcty_dim

  do i = -nctx, nctx
    xx = i * xsiz
    ic = nctx + 1 + i
    do j = -ncty, ncty
      yy = j * ysiz
      jc = ncty + 1 + j
      do k = -nctz, nctz
        zz = k * zsiz
        kc = nctz + 1 + k
        call cova3(0.0, 0.0, 0.0, xx, yy, zz, 1, nst, nst_max, c0, it, cc, aa, &
                   1, nst_max+1, rotmat, cmax, covtab(ic, jc, kc))
        hsqd = sqdist(0.0, 0.0, 0.0, xx, yy, zz, isrot, &
                      nst_max+1, rotmat)
        if (real(hsqd) <= radsqd) then
          nlooku = nlooku + 1

          ! We want to search by closest variogram distance (and use the
          ! anisotropic Euclidean distance to break ties:
          tmp(nlooku) = -(covtab(ic, jc, kc) - TINY * real(hsqd))
          order(nlooku) = real((kc - 1) * maxcxy + (jc - 1) * maxctx_dim + ic)
        end if
      end do
    end do
  end do

  ! Finished setting up the look-up table, now order the nodes such
  ! that the closest ones, according to variogram distance, are searched
  ! first. Note: the "loc" array is used because I didn't want to make
  ! special allowance for 2 byte integers in the sorting subroutine:

  call sortem(1, nlooku, tmp, 1, order, c, d, e, f, g, h)

  do il = 1, nlooku
    loc = int(order(il))
    iz = int((loc - 1) / maxcxy) + 1
    iy = int((loc - (iz - 1) * maxcxy - 1) / maxctx_dim) + 1
    ix = loc - (iz - 1) * maxcxy - (iy - 1) * maxctx_dim
    iznode(il) = int(iz, kind=2)
    iynode(il) = int(iy, kind=2)
    ixnode(il) = int(ix, kind=2)
  end do

  if (nodmax > nodmax_max) then
    write(ldbg, *)
    write(ldbg, *) 'The maximum number of close nodes = ', nodmax
    write(ldbg, *) 'this was reset from your specification due '
    write(ldbg, *) 'to storage limitations.'
    nodmax = nodmax_max
  end if

  ! Debugging output if requested:
  if (idbg < 2) return

  write(ldbg, *)
  write(ldbg, *) 'There are ', nlooku, ' nearby nodes that will be '
  write(ldbg, *) 'checked until enough close data are found.'
  write(ldbg, *)

  if (idbg < 14) return

  do i = 1, nlooku
    xx = (ixnode(i) - nctx - 1) * xsiz
    yy = (iynode(i) - ncty - 1) * ysiz
    zz = (iznode(i) - nctz - 1) * zsiz
    write(ldbg, 100) i, xx, yy, zz
  end do
100 format('Point ', i3, ' at ', 3f12.4)

  ! All finished:
  return

end subroutine ctable
