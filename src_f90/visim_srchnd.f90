subroutine srchnd(ix, iy, iz)
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
!               Search for nearby Simulated Grid nodes
!               **************************************
!
! The idea is to spiral away from the node being simulated and note all
! the nearby nodes that have been simulated.
!
!
!
! INPUT VARIABLES:
!
!   ix,iy,iz        index of the point currently being simulated
!   sim             the realization so far (from visim_grid_mod)
!   nodmax          the maximum number of nodes that we want
!   nlooku          the number of nodes in the look up table
!   i[x,y,z]node    the relative indices of those nodes
!   [x,y,z]mn       the origin of the global grid network
!   [x,y,z]siz      the spacing of the grid nodes
!
!
!
! OUTPUT VARIABLES:
!
!   ncnode          the number of close nodes
!   icnode()        the number in the look up table
!   cnode[x,y,z]()  the location of the nodes
!   cnodev()        the values at the nodes
!
!
!
!-----------------------------------------------------------------------
  use visim_params_mod
  use visim_grid_mod
  use visim_volume_mod
  use visim_covariance_mod
  use visim_search_mod
  implicit none

  ! Arguments
  integer, intent(in) :: ix, iy, iz

  ! Local variables
  integer :: ninoct(8)
  integer :: il, i, j, k, ind, idx, idy, idz, iq

  ! Consider all the nearby nodes until enough have been found:
  ncnode = 0
  if (noct > 0) then
    do i = 1, 8
      ninoct(i) = 0
    end do
  end if

  do il = 2, nlooku
    if (ncnode == nodmax) return

    i = ix + (int(ixnode(il)) - nctx - 1)
    j = iy + (int(iynode(il)) - ncty - 1)
    k = iz + (int(iznode(il)) - nctz - 1)

    if (i < 1 .or. j < 1 .or. k < 1) cycle
    if (i > nx .or. j > ny .or. k > nz) cycle

    ind = i + (j - 1) * nx + (k - 1) * nxy

    if (sim(ind) > UNEST) then
      ! Check the number of data already taken from this octant:
      if (noct > 0) then
        idx = ix - i
        idy = iy - j
        idz = iz - k

        if (idz > 0) then
          iq = 4
          if (idx <= 0 .and. idy > 0) iq = 1
          if (idx > 0 .and. idy >= 0) iq = 2
          if (idx < 0 .and. idy <= 0) iq = 3
        else
          iq = 8
          if (idx <= 0 .and. idy > 0) iq = 5
          if (idx > 0 .and. idy >= 0) iq = 6
          if (idx < 0 .and. idy <= 0) iq = 7
        end if

        ninoct(iq) = ninoct(iq) + 1
        if (ninoct(iq) > noct) cycle
      end if

      ncnode = ncnode + 1
      icnode(ncnode) = il
      cnodex(ncnode) = xmn + real(i - 1) * xsiz
      cnodey(ncnode) = ymn + real(j - 1) * ysiz
      cnodez(ncnode) = zmn + real(k - 1) * zsiz
      cnodev(ncnode) = sim(ind)
      cnodeindex(ncnode) = ind
    end if
  end do

  ! Return to calling program
  return

end subroutine srchnd
