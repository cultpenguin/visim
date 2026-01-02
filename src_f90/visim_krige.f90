subroutine krige(ix, iy, iz, xx, yy, zz, lktype, gmean, cmean, cstdev)
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
!            Builds and Solves the SK or OK Kriging System
!            *********************************************
!
! INPUT VARIABLES:
!
!   ix,iy,iz        index of the point currently being simulated
!   xx,yy,zz        location of the point currently being simulated
!   lktype          kriging type (0=SK, 1=OK, 2=LVM, 3=ExtDrift, 4=Collocated)
!   gmean           global mean
!
!
!
! OUTPUT VARIABLES:
!
!   cmean           kriged estimate
!   cstdev          kriged standard deviation
!
!
!
! EXTERNAL REFERENCES: ksol   Gaussian elimination system solution
!                      cova3  Covariance calculation
!
!
! ORIGINAL: C.V. Deutsch                               DATE: August 1990
!-----------------------------------------------------------------------
  use visim_params_mod
  use visim_data_mod
  use visim_grid_mod
  use visim_covariance_mod
  use visim_search_mod
  use visim_kriging_mod
  use visim_histogram_mod
  implicit none

  ! Arguments
  integer, intent(in) :: ix, iy, iz, lktype
  real, intent(in) :: xx, yy, zz, gmean
  real, intent(out) :: cmean, cstdev

  ! Local variables
  logical :: first
  real :: spos(maxkr1_max)
  integer :: ix1, ix2, iy1, iy2, iz1, iz2
  integer :: na, neq, in, i, j, index, ind, ii, jj, kk, ising
  real :: x1, y1, z1, x2, y2, z2, cov
  real :: edmin, edmax, sfmin, sfmax, sumwts
  real :: wmin, wmean

  ! External GSLIB functions
  external :: cova3, ksol

  if (idbg > 14) then
    write(*, *) 'DSSIM KRIGING'
  end if

  ! Size of the kriging system:
  first = .false.
  na = nclose + ncnode

  if (lktype == 0) neq = na
  if (lktype == 1) neq = na + 1
  if (lktype == 2) neq = na
  if (lktype == 3) neq = na + 2
  if (lktype == 4) neq = na + 1

  ! Set up kriging matrices:
  in = 0
  do j = 1, na
    ! Sort out the actual location of point "j"
    if (j <= nclose) then
      index = int(close(j))
      x1 = x(index)
      y1 = y(index)
      z1 = z(index)
      vra(j) = vr(index)
      vrea(j) = sec(index)
    else
      ! It is a previously simulated node (keep index for table look-up):
      index = j - nclose
      x1 = cnodex(index)
      y1 = cnodey(index)
      z1 = cnodez(index)
      vra(j) = cnodev(index)
      ind = icnode(index)
      ix1 = ix + (int(ixnode(ind)) - nctx - 1)
      iy1 = iy + (int(iynode(ind)) - ncty - 1)
      iz1 = iz + (int(iznode(ind)) - nctz - 1)
      index = ix1 + (iy1 - 1) * nx + (iz1 - 1) * nxy
      vrea(j) = lvm(index)
    end if

    do i = 1, j
      ! Sort out the actual location of point "i"
      if (i <= nclose) then
        index = int(close(i))
        x2 = x(index)
        y2 = y(index)
        z2 = z(index)
      else
        ! It is a previously simulated node (keep index for table look-up):
        index = i - nclose
        x2 = cnodex(index)
        y2 = cnodey(index)
        z2 = cnodez(index)
        ind = icnode(index)
        ix2 = ix + (int(ixnode(ind)) - nctx - 1)
        iy2 = iy + (int(iynode(ind)) - ncty - 1)
        iz2 = iz + (int(iznode(ind)) - nctz - 1)
      end if

      ! Now, get the covariance value:
      in = in + 1

      ! Decide whether or not to use the covariance look-up table:
      if (j <= nclose .or. i <= nclose) then
        call cova3(x1, y1, z1, x2, y2, z2, 1, nst, nst_max, c0, it, &
                   cc, aa, 1, nst_max+1, rotmat, cmax, cov)
        a(in) = dble(cov)
      else
        ! Try to use the covariance look-up (if the distance is in range):
        ii = nctx + 1 + (ix1 - ix2)
        jj = ncty + 1 + (iy1 - iy2)
        kk = nctz + 1 + (iz1 - iz2)
        if (ii < 1 .or. ii > maxctx_dim .or. &
            jj < 1 .or. jj > maxcty_dim .or. &
            kk < 1 .or. kk > maxctz_dim) then
          call cova3(x1, y1, z1, x2, y2, z2, 1, nst, nst_max, &
                     c0, it, cc, aa, 1, nst_max+1, rotmat, cmax, cov)
        else
          cov = covtab(ii, jj, kk)
        end if
        a(in) = dble(cov)
      end if
    end do

    ! Get the RHS value (possibly with covariance look-up table):
    if (j <= nclose) then
      call cova3(xx, yy, zz, x1, y1, z1, 1, nst, nst_max, c0, it, cc, aa, &
                 1, nst_max+1, rotmat, cmax, cov)
      r(j) = dble(cov)
    else
      ! Try to use the covariance look-up (if the distance is in range):
      ii = nctx + 1 + (ix - ix1)
      jj = ncty + 1 + (iy - iy1)
      kk = nctz + 1 + (iz - iz1)
      if (ii < 1 .or. ii > maxctx_dim .or. &
          jj < 1 .or. jj > maxcty_dim .or. &
          kk < 1 .or. kk > maxctz_dim) then
        call cova3(xx, yy, zz, x1, y1, z1, 1, nst, nst_max, &
                   c0, it, cc, aa, 1, nst_max+1, rotmat, cmax, cov)
      else
        cov = covtab(ii, jj, kk)
      end if
      r(j) = dble(cov)
    end if
    rr(j) = r(j)
  end do

  ! Addition of OK constraint:
  if (lktype == 1 .or. lktype == 3) then
    do i = 1, na
      in = in + 1
      a(in) = 1.0
    end do
    in = in + 1
    a(in) = 0.0
    r(na + 1) = 1.0
    rr(na + 1) = 1.0
  end if

  ! Addition of the External Drift Constraint:
  if (lktype == 3) then
    edmin = 999999.
    edmax = -999999.
    do i = 1, na
      in = in + 1
      a(in) = vrea(i)
      if (a(in) < edmin) edmin = a(in)
      if (a(in) > edmax) edmax = a(in)
    end do
    in = in + 1
    a(in) = 0.0
    in = in + 1
    a(in) = 0.0
    ind = ix + (iy - 1) * nx + (iz - 1) * nxy
    r(na + 2) = dble(lvm(ind))
    rr(na + 2) = r(na + 2)
    if ((edmax - edmin) < EPSLON) neq = neq - 1
  end if

  ! Addition of Collocated Cosimulation Constraint:
  if (lktype == 4) then
    sfmin = 1.0e21
    sfmax = -1.0e21
    do i = 1, na
      in = in + 1
      a(in) = colocorr * r(i)
      if (a(in) < sfmin) sfmin = a(in)
      if (a(in) > sfmax) sfmax = a(in)
    end do
    in = in + 1
    a(in) = 1.0
    ii = na + 1
    r(ii) = dble(colocorr)
    rr(ii) = r(ii)
  end if

  ! Write out the kriging Matrix if Seriously Debugging:
  if (idbg >= 333) then
    write(ldbg, 100) ix, iy, iz
    write(*, 100) ix, iy, iz
    ii = 1
    do i = 1, neq
      jj = ii + i - 1
      write(ldbg, 101) i, r(i), (a(j), j = ii, jj)
      write(*, 101) i, r(i), (a(j), j = ii, jj)
      ii = ii + i
    end do
100 format(/, 'Kriging Matrices for Node: ', 3i4, ' RHS first')
101 format('    r(', i2, ') =', f7.4, '  a= ', 99f7.4)
  end if

  ! Solve the Kriging System:
  if (neq == 1 .and. lktype /= 3) then
    s(1) = r(1) / a(1)
    ising = 0
  else
    call ksol(1, neq, 1, a, r, s, ising)
  end if

  ! Write a warning if the matrix is singular:
  if (ising /= 0) then
    if (idbg >= 331) then
      write(ldbg, *) 'WARNING : singular matrix'
      write(ldbg, *) '          for node', ix, iy, iz
    end if
    cmean = gmean
    cstdev = sqrt(gvar)
    return
  end if

  ! Compute the estimate and kriging variance.  Recall that kriging type
  !     0 = Simple Kriging:
  !     1 = Ordinary Kriging:
  !     2 = Locally Varying Mean:
  !     3 = External Drift:
  !     4 = Collocated Cosimulation:

  cmean = 0.0
  cbb = gvar  ! Use gvar as the baseline variance
  cstdev = cbb
  sumwts = 0.0

  do i = 1, na
    cmean = cmean + real(s(i)) * vra(i)
    cstdev = cstdev - real(s(i) * rr(i))
    sumwts = sumwts + real(s(i))
  end do

  if (lktype == 0) cmean = cmean + (1.0 - sumwts) * gmean

  if (lktype == 1) cstdev = cstdev - real(s(na + 1))

  if (lktype == 2) cmean = cmean + gmean

  if (lktype == 4) then
    ind = ix + (iy - 1) * nx + (iz - 1) * nxy
    cmean = cmean + real(s(na + 1)) * lvm(ind)
    cstdev = cstdev - real(s(na + 1) * rr(na + 1))
  end if

  ! If cmean negative, and in case the local conditional distribution
  ! is lognormal (idrawopt=1), then the weights s(1....na+1) are shifted
  ! such that cmean is recalculated to be positive
  if (cmean <= 0.0) then
    write(ldbg, *) 'Before changing : cmean, cstdev ', cmean, cstdev
    if (idrawopt == 9999) then
      ! REMOVED IN VISIM - this section is disabled

      wmin = 9999.9
      do i = 1, neq
        if (s(i) <= wmin) wmin = real(s(i))
      end do
      if (lktype == 0) then
        if ((1 - sumwts) <= wmin) wmin = 1 - sumwts
      end if

      do i = 1, neq
        spos(i) = real(s(i)) + abs(wmin)
      end do

      if (lktype == 0) then
        wmean = 1 - sumwts + abs(wmin)
      end if

      cmean = 0.0
      sumwts = 0.0

      do i = 1, na
        cmean = cmean + spos(i) * vra(i)
        sumwts = sumwts + real(s(i))
      end do

      if (lktype == 0) cmean = cmean + wmean * gmean

      if (lktype == 2) cmean = cmean + gmean

      if (lktype == 4) then
        ind = ix + (iy - 1) * nx + (iz - 1) * nxy
        cmean = cmean + spos(na + 1) * lvm(ind)
      end if

      do i = 1, neq
        write(ldbg, *) real(s(i)), spos(i)
      end do
    end if
  end if

  ! Error message if negative variance:
  if (cstdev < 0.0) then
    write(ldbg, *) 'ERROR: Negative Variance: ', cstdev
    cstdev = 0.0
  end if

  cstdev = sqrt(cstdev)

  ! Write out the kriging Weights if Seriously Debugging:
  if (idbg >= 333) then
    do i = 1, na
      write(ldbg, 140) i, vra(i), s(i)
      write(*, 140) i, vra(i), s(i)
    end do
140 format(' Data ', i4, ' value ', f10.4, ' weight ', f10.4)
    if (lktype == 4) write(ldbg, 141) lvm(ind), s(na + 1)
    if (lktype == 4) write(*, 141) lvm(ind), s(na + 1)
141 format(' Sec Data  value ', f10.4, ' weight ', f10.4)
    write(ldbg, 142) gmean, cmean, cstdev
    write(*, 142) gmean, cmean, cstdev
142 format(' Global mean ', f10.4, ' conditional ', f10.4, &
         ' std dev ', f10.4)
  end if

  ! Finished Here:
  return

end subroutine krige
