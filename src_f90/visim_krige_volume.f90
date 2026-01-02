subroutine krige_volume(ix, iy, iz, xx, yy, zz, lktype, &
                        gmean, cmean, cstdev, sim_index)
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
!     Builds and Solves the SK Kriging System
!     in case volume average data is present
!     *********************************************
!
! INPUT VARIABLES:
!
!   ix,iy,iz        index of the point currently being simulated
!   xx,yy,zz        location of the point currently being simulated
!   sim_index       index of point being simulated
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
!
!
! Consider implementing Kriging with a locally varying mean and OK
! Make volobs_ref a global variable (right now calculated in each ite)
! volobs_ref could be read from..
!
!
! ORIGINAL: C.V. Deutsch                               DATE: August 1990
! REVISION : Thomas Mejer Hansen                       DATE: June 2004
! including volume average data
!-----------------------------------------------------------------------
  use visim_params_mod
  use visim_data_mod
  use visim_grid_mod
  use visim_volume_mod
  use visim_covariance_mod
  use visim_search_mod
  use visim_kriging_mod
  implicit none

  ! Arguments
  integer, intent(in) :: ix, iy, iz, lktype, sim_index
  real, intent(in) :: xx, yy, zz, gmean
  real, intent(out) :: cmean, cstdev

  ! Local variables
  logical :: first
  real :: spos(maxkr1_max)
  real :: covsum, rdummy
  integer :: na, neq, in, index, ind
  integer :: iv1, iv2
  integer :: iray1, iray2, volindex
  integer :: neq_read, ising
  real :: vvcov
  integer :: i, j, is, ie
  integer :: ix1, iy1, iz1, ix2, iy2, iz2
  real :: x1, y1, z1, x2, y2, z2, cov
  real :: sumwts

  ! External GSLIB functions
  external :: cova3, ksol, cov_data2vol, cov_vol2vol

  if (lktype /= 0) then
    write(*, *) 'VISIM CURRENTLY ONLY WORKS FOR SIMPLE KRIGING'
    stop
  end if

  ! Size of the kriging system:
  ! NUMBER OF CONDITIONAL DATA
  first = .false.
  na = nclose + ncnode

  if (idbg > 3) then
    write(*, *) '***********'
    write(*, *) 'nclose, ncnode= ', nclose, ncnode
    do j = 1, na
      if (j <= nclose) then
        index = int(close(i))
      else
        index = j - nclose
      end if
      write(*, *) 'na=', na, ' j=', j, ' index=', index
    end do
  end if

  ! NUMBER OF EQUATIONS
  neq = na + nusev
  if (idbg >= 11) then
    write(*, *) 'Using na=', na, ' nusev=', nusev, &
                ' nclose, ncnode= ', nclose, ncnode
  end if

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

      call cova3(x1, y1, z1, x2, y2, z2, 1, nst, nst_max, &
                 c0, it, cc, aa, 1, nst_max+1, rotmat, cmax, cov)
      a(in) = dble(cov)

      ! This is where one should add uncertainty of POINT DATA
      if (i == j) then
        ! a(in) = a(in) + 0.1
      end if
    end do

    ! Get the RHS value (possibly with covariance look-up table):
    call cova3(xx, yy, zz, x1, y1, z1, 1, nst, nst_max, c0, it, &
               cc, aa, 1, nst_max+1, rotmat, cmax, cov)
    r(j) = dble(cov)
    rr(j) = r(j)
  end do
  ! ENDED LOOPING OVER DATA i

  if (nusev > 0) then
    ! write(*,*) 'setting up kriging system for volume data'
    do iv1 = 1, nusev
      iray1 = usev(iv1)

      ! SETUP UNKNOWN TO VOLUME
      call cov_data2vol(sim_index, xx, yy, zz, iray1, vvcov)
      r(na + iv1) = dble(vvcov)
      rr(na + iv1) = dble(vvcov)

      ! SETUP VOLUME TO DATA
      ! A lookup table should be considered to increase performance !!!
      do index = 1, na
        x1 = cnodex(index)
        y1 = cnodey(index)
        z1 = cnodez(index)
        in = in + 1

        call cov_data2vol(cnodeindex(index), x1, y1, z1, iray1, vvcov)
        a(in) = dble(vvcov)
      end do

      ! SETUP VOLUME TO VOLUME
      do iv2 = 1, iv1
        in = in + 1
        iray2 = usev(iv2)
        call cov_vol2vol(iray1, iray2, vvcov)
        a(in) = dble(vvcov) + datacov(iray1, iray2)
        if (idbg >= 3) then
          write(*, *) 'a,in,iray1,iray2,datacov,vvcov=', &
                      a(in), in, iray1, iray2, datacov(iray1, iray2), vvcov
        end if
      end do
    end do
  end if

  ! Write out the kriging Matrix if Seriously Debugging:
  if (idbg >= 3) then
    write(ldbg, 100) ix, iy, iz
    is = 1
    do i = 1, neq
      ie = is + i - 1
      write(ldbg, 101) i, r(i), (a(j), j = is, ie)
      write(*, 101) i, r(i), (a(j), j = is, ie)
      is = is + i
    end do
100 format(/, 'Kriging Matrices for Node: ', 3i4, ' RHS first')
101 format('   ! r(', i2, ') = ', f12.8, '  a= ', 99f13.8, ' ')
  end if

  ! Solve the Kriging System:
  if (read_lambda == 1) then
    ! reads lambda from file
    ! do NOT compute lambda
    read(99) neq_read
    read(99) ising
    read(99) (s(i), i = 1, neq)
  else
    if (neq == 1 .and. lktype /= 3) then
      s(1) = r(1) / a(1)
      ising = 0
    else
      call ksol(1, neq, 1, a, r, s, ising)
    end if
  end if

  if (read_lambda == 0) then
    write(99) (neq)
    write(99) (ising)
    write(99) (s(i), i = 1, neq)
  end if

  if (idbg >= 4) then
    do i = 1, na
      write(*, 140) i, vra(i), s(i)
    end do
    do i = 1, nusev
      write(*, 140) i + na, volobs(usev(i)), s(i + na)
    end do
  end if

  ! Write a warning if the matrix is singular:
  if (ising /= 0) then
    if (idbg >= 1) then
      write(*, *) 'WARNING : singular matrix'
      write(*, *) '          for node', ix, iy, iz, sim_index
      write(*, *) 'ASSIGNING GLOBAL MEAN AND VAR !!!!'
      write(*, *) '**********************************'
    end if
    write(*, *) 'Singular Matrix   sim_index=', sim_index
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

  ! cbb is the unknown data variance
  cmean = 0.0
  cstdev = cbb
  sumwts = 0.0

  do i = 1, na
    rdummy = (vra(i) - gmean)
    cmean = cmean + real(s(i)) * rdummy
    cstdev = cstdev - real(s(i) * rr(i))
    sumwts = sumwts + real(s(i))
    if (idbg >= 4) then
      write(*, *) 'A CMEAN=', i, cmean, cstdev, s(i), &
                  ' r=', r(i), ' rr=', rr(i)
    end if
  end do

  if (nusev > 0) then
    do i = 1, nusev
      rdummy = (volobs(usev(i)) - volobs_ref(usev(i)))
      cmean = cmean + real(s(i + na)) * rdummy
      cstdev = cstdev - real(s(i + na) * rr(i + na))
      sumwts = sumwts + real(s(i + na))
      if (idbg >= 4) then
        write(*, *) 'B CMEAN, s=', s(i + na)
        write(*, *) 'B CMEAN, volobs(usev(i))=', volobs(usev(i)), &
                    'r=', r(i + na), ' rr=', rr(i + na)
        write(*, *) 'B CMEAN, volobs_ref(ray)=', volobs_ref(usev(i))
        write(*, *) 'B CMEAN, v_obs-v0=', rdummy
        write(*, *) 'B CMEAN, WEIGHT=', s(i + na)
        write(*, *) 'B CMEAN, (v_obs-v0)*W=', rdummy * s(i + na)
        write(*, *) 'B CMEAN=', cmean, cstdev, s(i + na), volobs(i), &
                    real(s(i + na)) * (volobs(i) - volobs_ref(usev(i)))
        write(*, *) '--'
      end if
    end do
  end if

  if (lktype == 0) cmean = gmean + cmean

  ! Error message if negative variance:
  if (cstdev < 0.0) then
    write(ldbg, *) 'ERROR: Negative Variance: ', cstdev
    cstdev = 0.0
  end if

  ! TO GET STANDARD DEVIATION TAKE SQRT(VAR)
  cstdev = sqrt(cstdev)

  ! Write out the kriging Weights if Seriously Debugging:
  if (idbg >= 1113) then
    write(*, *) 'DEBIGGGGGGGGGGGGGGGGGGGGg'
    do i = 1, na
      write(ldbg, 140) i, vra(i), s(i)
      write(*, 140) i, vra(i), s(i)
    end do
    do i = 1, nusev
      write(ldbg, 140) na + i, vra(i), s(i)
      write(*, 140) i + na, volobs(usev(i)), s(na + i)
    end do

140 format(' Data ', i4, ' value ', f12.4, ' weight ', f12.4)
    if (lktype == 4) write(ldbg, 141) lvm(ind), s(na + 1)
141 format(' Sec Data  value ', f12.4, ' weight ', f12.4)
    write(ldbg, 142) gmean, cmean, cstdev
    write(*, 142) gmean, cmean, cstdev
142 format(' Global mean ', f12.4, ' conditional ', f12.4, &
         ' std dev ', f12.4)
  end if

  ! Finished Here:
  return

end subroutine krige_volume
