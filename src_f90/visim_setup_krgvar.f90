subroutine setup_krgvar
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
!          Set up the Kriging Variance Matrix
!          ***********************************
!
! If conditional simulation is made and the kriging variance
! matrix is calculated instead of being read from a user specified
! file(localfl), then the kriging variance matrix is set up for future
! use in trans.
!
! inovar:  number of grid nodes that cannot be reached by kriging
!          radius search
! zmaxvar: max kriging variance that can be obtained.
! novar(): location index for those grid nodes that cannot be reached.
!
!-----------------------------------------------------------------------
  use visim_params_mod
  use visim_data_mod
  use visim_grid_mod
  use visim_covariance_mod
  use visim_search_mod
  use visim_histogram_mod
  implicit none

  ! Local variables
  real*8 :: acorni
  logical :: testind
  integer :: is_local, isrot_local
  integer :: nsec, nxsup, nysup, nzsup
  real :: sec2, sec3, xmnsup, ymnsup, zmnsup, xsizsup, ysizsup, zsizsup
  integer :: ind, ix, iy, iz, id, id2, in_local, index_local, itt
  real :: xx, yy, zz, test, test2, TINY
  integer :: inovar_local, irepo
  real :: zmaxvar
  real :: cmean, cstdev, gmean
  real :: lktype
  real :: radsqd_original
  integer :: infoct

  ! External GSLIB functions
  external :: setrot, setsupr, picksup, getindx, srchsupr

  ! Increase search radius by 1.5 for kriging variance calculation
  radsqd_original = radsqd
  radsqd = radsqd * 1.5 * 1.5

  write(*, *) 'Setting up kriging variance'

  ! Set up rotation matrices for variogram and search
  if (idbg > 0) then
    write(ldbg, *) 'Setting up rotation matrices for variogram and search'
  end if

  do is_local = 1, nst(1)
    call setrot(ang1(is_local), ang2(is_local), ang3(is_local), &
                anis1(is_local), anis2(is_local), &
                is_local, nst_max+1, rotmat)
  end do
  isrot_local = nst_max + 1
  call setrot(sang1, sang2, sang3, sanis1, sanis2, isrot_local, nst_max+1, rotmat)

  ! Set up the super block search
  if (sstrat == 0) then
    if (idbg > 0) then
      write(ldbg, *) 'Setting up super block search strategy'
    end if
    nsec = 1
    call setsupr(nx, xmn, xsiz, ny, ymn, ysiz, nz, zmn, zsiz, nd, x, y, z, &
                 vr, wt, nsec, sec, sec2, sec3, maxsbx_dim, maxsby_dim, maxsbz_dim, &
                 nisb, nxsup, xmnsup, xsizsup, nysup, ymnsup, ysizsup, &
                 nzsup, zmnsup, zsizsup)
    call picksup(nxsup, xsizsup, nysup, ysizsup, nzsup, zsizsup, &
                 isrot_local, nst_max+1, rotmat, radsqd, nsbtosr, ixsbtosr, &
                 iysbtosr, izsbtosr)
  end if

  ! Set up the covariance table and the spiral search
  call ctable()

  ! Initialize the grid
  do ind = 1, nxyz
    sim(ind) = UNEST
  end do

  ! Assign sample data to the closest grid node
  TINY = 0.0001

  do id = 1, nd
    call getindx(nx, xmn, xsiz, x(id), ix, testind)
    call getindx(ny, ymn, ysiz, y(id), iy, testind)
    call getindx(nz, zmn, zsiz, z(id), iz, testind)
    ind = ix + (iy - 1) * nx + (iz - 1) * nxy
    xx = xmn + real(ix - 1) * xsiz
    yy = ymn + real(iy - 1) * ysiz
    zz = zmn + real(iz - 1) * zsiz
    test = abs(xx - x(id)) + abs(yy - y(id)) + abs(zz - z(id))

    ! Assign this sample data to the nearest node unless there is a closer sample
    if (sstrat == 1) then
      if (sim(ind) >= 0.0) then
        id2 = int(sim(ind) + 0.5)
        test2 = abs(xx - x(id2)) + abs(yy - y(id2)) + abs(zz - z(id2))
        if (test <= test2) sim(ind) = real(id)
        if (idbg > 0) then
          write(ldbg, 102) id, id2
        end if
      else
        sim(ind) = real(id)
      end if
    end if

    ! If data is too close to a grid node (<TINY), assign flag
    if (sstrat == 0 .and. test <= TINY) sim(ind) = 10.0 * UNEST
  end do

102 format(' WARNING data values ', 2i5, ' are both assigned to ', &
           /, '         the same node - taking the closest')

  ! Now, enter data values into the grid
  do ind = 1, nxyz
    id = int(sim(ind) + 0.5)
    if (id > 0) sim(ind) = vr(id)
  end do

  irepo = max(1, min((nxyz / 10), 10000))

  ! MAIN LOOP OVER ALL THE NODES TO GET THE KRIGING VARIANCE
  ! Note: novar array is already allocated in visim_grid_mod
  if (idbg >= 3) then
    write(ldbg, *) 'Sample data location and grid search'
  end if

  inovar_local = 0
  zmaxvar = 0.0

  do in_local = 1, nxyz
    index_local = int(in_local + 0.5)

    if (idbg >= 3) then
      write(ldbg, *) 'SIM(', index_local, ')=', sim(index_local)
    end if

    ! Skip if data is assigned to grid node or too close
    if (sim(index_local) > (UNEST + EPSLON) .or. &
        sim(index_local) < (UNEST * 2.0)) then
      krgvar(index_local) = 0.0
      cycle
    end if

    iz = int((index_local - 1) / nxy) + 1
    iy = int((index_local - (iz - 1) * nxy - 1) / nx) + 1
    ix = index_local - (iz - 1) * nxy - (iy - 1) * nx
    xx = xmn + real(ix - 1) * xsiz
    yy = ymn + real(iy - 1) * ysiz
    zz = zmn + real(iz - 1) * zsiz

    ! Search for neighboring data
    if (sstrat == 0) then
      call srchsupr(xx, yy, zz, radsqd, isrot_local, nst_max+1, &
                    rotmat, nsbtosr, ixsbtosr, iysbtosr, &
                    izsbtosr, noct, nd, x, y, z, wt, nisb, nxsup, &
                    xmnsup, xsizsup, nysup, ymnsup, ysizsup, &
                    nzsup, zmnsup, zsizsup, nclose, close, infoct)

      if (idbg > 0) then
        write(ldbg, *) 'There are nclose=', nclose, ' in the search radius.'
        write(*, *) 'There are nclose=', nclose, ' in the search radius.'
      end if

      ! Need at least 2 data for kriging variance calculation
      if (nclose < 2) then
        inovar_local = inovar_local + 1
        novar(inovar_local) = in_local
        cycle
      end if

      if (nclose > ndmax) nclose = ndmax
    else
      call srchnd(ix, iy, iz)

      if (idbg >= 3) then
        write(ldbg, *) 'There are ncnode=', ncnode, ' in the search radius.'
      end if

      if (ncnode < 2) then
        inovar_local = inovar_local + 1
        novar(inovar_local) = in_local
        cycle
      end if

      if (ncnode > nodmax) ncnode = nodmax
    end if

    ! Get global mean
    if (ktype == 2) then
      gmean = lvm(index_local)
    else
      gmean = skgmean
    end if

    ! Perform the kriging
    lktype = ktype
    if (ktype == 1 .and. (nclose + ncnode) < 4) lktype = 0

    call krige(ix, iy, iz, xx, yy, zz, lktype, gmean, cmean, cstdev)

    krgvar(index_local) = cstdev * cstdev
    if (krgvar(index_local) >= zmaxvar) zmaxvar = krgvar(index_local)
  end do

  ! For nodes that have not been visited, assign max variance
  do in_local = 1, inovar_local
    index_local = novar(in_local)
    krgvar(index_local) = zmaxvar
  end do

  if (idbg >= 3) then
    write(*, *) 'The kriging variance at each grid node is given as follows'
    do itt = 1, nxyz
      write(ldbg, *) 'node index =', itt, 'kriging variance =', krgvar(itt)
    end do
  end if

  ! Restore original radius
  radsqd = radsqd_original

  return

end subroutine setup_krgvar
