subroutine visim
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
!     Conditional Simulation of a 3-D Rectangular Grid
!     ************************************************
!
!     This subroutine generates 3-D realizations of a sequential process with
!     a given autocovariance model, and conditional to input sample data.
!     The conditional simulation is achieved by sequential simulation of all
!     the nodes visited by a random path.
!
!
! ORIGINAL: C.V. Deutsch, Thomas Mejer Hansen
! CONVERTED: F90 version 2026
!-----------------------------------------------------------------------
  use visim_params_mod
  use visim_data_mod
  use visim_grid_mod
  use visim_volume_mod
  use visim_covariance_mod
  use visim_kriging_mod
  use visim_search_mod
  use visim_histogram_mod
  use visim_random_mod
  implicit none

  ! Local variables
  real :: randnu(1), var(10), vobs, derr
  real*8 :: p, acorni, cp, oldcp, w
  logical :: testind
  real :: cstdev_tmp
  real :: sim_mean(nxyz), sim_std(nxyz)
  real :: sumderr, sumerr, temp
  real :: meantmh, stdtmh
  real :: gvar_org, gmean_org, cbb_org
  real :: av
  integer :: tstep
  integer :: c, d, e, f, g, h
  integer :: in_local, ind, index_local, iy, ix, iz
  integer :: ix1, iy1, iz1, jx, jy, j, jz, id, i, id2
  integer :: is_local, irepo, isrot_local
  real :: cmean, cstdev, gmean
  real :: lktype
  integer :: n_mean, n_var
  character(len=80) :: tmpfl
  integer :: ivol_local
  real :: xx, yy, zz, test, test2
  real :: TINY
  integer :: nnx, nny, nnz, imult_local
  integer :: ne
  real :: ss, simval
  ! Super block search variables (local to this routine)
  integer :: nsec, nxsup, nysup, nzsup
  real :: sec2, sec3, xmnsup, ymnsup, zmnsup, xsizsup, ysizsup, zsizsup
  ! Stats variables
  integer :: neg, nsmall, nsmall0, nlarge
  integer :: infoct

  ! External GSLIB and VISIM functions
  external :: setrot, setsupr, picksup, sortem, getindx, acorni, srchsupr
  real :: simu  ! External function from visim_simu.f90

  ! Set up rotation matrices for variogram and search
  do is_local = 1, nst(1)
    call setrot(ang1(is_local), ang2(is_local), ang3(is_local), &
                anis1(is_local), anis2(is_local), &
                is_local, nst_max+1, rotmat)
  end do
  isrot_local = nst_max + 1
  call setrot(sang1, sang2, sang3, sanis1, sanis2, isrot_local, nst_max+1, rotmat)

  ! Set up the super block search
  if (sstrat == 0) then
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

  ! In the case of collocated cokriging, secondary variable is available
  ! at every grid for each realization
  if (isim > 1 .and. ktype == 4) then
    if (idbg > 0) write(*, *) ' Reading next secondary model'
    index_local = 0
    do iz = 1, nz
      do iy = 1, ny
        do ix = 1, nx
          index_local = index_local + 1
          read(llvm, *, end=977) (var(j), j=1, nvaril)
          lvm(index_local) = var(icollvm)
          sim(index_local) = real(index_local)
        end do
      end do
    end do

    if (idbg > 0) write(*, *) ' Building CDF from secondary model'
    call sortem(1, nxyz, lvm, 1, sim, c, d, e, f, g, h)
    oldcp = 0.0
    cp = 0.0
    do i = 1, nxyz
      cp = cp + dble(1.0 / real(nxyz))
      w = (cp + oldcp) / 2.0
      lvm(i) = lvm(i) * w
      oldcp = cp
    end do

    if (idbg > 0) write(*, *) ' Restoring order of secondary model'
    call sortem(1, nxyz, sim, 1, lvm, c, d, e, f, g, h)
977 continue
  end if

  ! Work out a random path for this realization
  do ind = 1, nxyz
    sim(ind) = real(acorni(idum))
    order(ind) = ind
  end do

  ! The multiple grid search works with multiples of 4
  if (densitypr == 0) then
    mults = 1
    nmult = 4
  else
    mults = 0
    nmult = 4
  end if

  if (mults == 1) then
    do imult_local = 1, nmult
      nnz = max(1, nz / (imult_local * 4))
      nny = max(1, ny / (imult_local * 4))
      nnx = max(1, nx / (imult_local * 4))
      jz = 1
      jy = 1
      jx = 1
      do iz = 1, nnz
        if (nnz > 1) jz = iz * imult_local * 4
        do iy = 1, nny
          if (nny > 1) jy = iy * imult_local * 4
          do ix = 1, nnx
            if (nnx > 1) jx = ix * imult_local * 4
            index_local = jx + (jy - 1) * nx + (jz - 1) * nxy
            sim(index_local) = sim(index_local) - imult_local
          end do
        end do
      end do
    end do
  end if

  if (idbg > 0) write(*, *) '-----------------------------'
  if (idbg > -1) write(*, *) 'Working on realization number ', isim

  ! SETUP THE RANDOM PATH - NEW STYLE
  call rayrandpath(order)

  ! READ/WRITE RANDOM PATH FROM/TO DISK?
  if (read_randpath == 0) then
    write(98) (order(i), i=1, nxyz)
  end if
  if (read_randpath == 1) then
    read(98) (order(i), i=1, nxyz)
  end if

  ! OPEN HANDLE FOR KRIGING MEAN + VAR
  tmpfl = 'kriging' // '_' // outfl
  open(lout_krig, file=tmpfl, status='unknown')

  ! Initialize the simulation
  do ind = 1, nxyz
    sim(ind) = UNEST
  end do

  ! Assign the sample data to the closest grid node
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

    ! Assign sample data to the closest grid node unless there is a close data
    if (sstrat == 1) then
      if (sim(ind) >= 0.0) then
        id2 = int(sim(ind) + 0.5)
        test2 = abs(xx - x(id2)) + abs(yy - y(id2)) + abs(zz - z(id2))
        if (test <= test2) sim(ind) = real(id)
      else
        sim(ind) = real(id)
      end if
    end if

    ! In case when data are not assigned to grid node, assign a flag
    if (sstrat == 0 .and. test <= TINY) then
      sim(ind) = 10.0 * UNEST
    end if
  end do

  ! Now, enter data values into the simulated grid
  do ind = 1, nxyz
    id = int(sim(ind) + 0.5)
    if (id > 0) sim(ind) = vr(id)
  end do

  irepo = max(1, min((nxyz / 10), 10000))

  ! MAIN LOOP OVER ALL THE NODES
  if (idbg > 0) print *, 'ok before the main loop?'

  neg = 0
  nsmall0 = 0
  nsmall = 0
  nlarge = 0

  if (doestimation == 1) then
    do ind = 1, nxyz
      sim_mean(ind) = sim(ind)
      sim_std(ind) = 0
    end do
  end if

  tstep = 5000000
  if (idbg >= -1) tstep = 10000
  if (idbg >= 0) tstep = 1000
  if (idbg >= 1) tstep = 100
  if (idbg >= 2) tstep = 1

  do in_local = 1, nxyz
    if (((in_local / tstep) * tstep == in_local) .and. (idbg >= 0)) then
      write(*, 103) in_local
103   format('************   currently on node ', i9, ' *****')
    end if

    ! Figure out the location of this point
    index_local = int(order(in_local) + 0.5)

    ! CHECK IF SAMPLE IS ALREADY CONDITIONED
    if ((sim(index_local) /= UNEST) .or. (mask(index_local) == 0)) then
      if (index_local <= 5 .and. idbg >= 0) then
        write(*,*) 'DEBUG: Skipping node', index_local, ' sim=', sim(index_local), ' mask=', mask(index_local)
      end if
      cycle
    end if

    iz = int((index_local - 1) / nxy) + 1
    iy = int((index_local - (iz - 1) * nxy - 1) / nx) + 1
    ix = index_local - (iz - 1) * nxy - (iy - 1) * nx

    if (index_local <= 5 .and. idbg >= 0) then
      write(*,*) 'DEBUG: Processing node', index_local, ' ix=', ix, ' iy=', iy, ' iz=', iz
    end if

    xx = xmn + real(ix - 1) * xsiz
    yy = ymn + real(iy - 1) * ysiz
    zz = zmn + real(iz - 1) * zsiz

    if (idbg >= 4) then
      write(ldbg, *) 'index', iz, iy, ix
      write(ldbg, *) '     ', zz, yy, xx
      write(*, *) 'index', ix, iy, iz
      write(*, *) '     ', xx, yy, zz
    end if

    ! Get the close data
    if (sstrat == 0) then
      call srchsupr(xx, yy, zz, radsqd, isrot, nst_max+1, &
                    rotmat, nsbtosr, ixsbtosr, iysbtosr, &
                    izsbtosr, noct, nd, x, y, z, wt, nisb, nxsup, &
                    xmnsup, xsizsup, nysup, ymnsup, ysizsup, &
                    nzsup, zmnsup, zsizsup, nclose, close, infoct)

      if (index_local <= 5) then
        write(*,*) 'DEBUG: Node', index_local, ' nclose=', nclose, ' ndmin=', ndmin
      end if

      if (nclose < ndmin) then
        ! assign global mean and variance
        if (index_local <= 5) then
          write(*,*) 'DEBUG: Node', index_local, ' nclose < ndmin, using gmean=', skgmean
        end if
        cmean = skgmean
        cstdev = sqrt(gvar)
        goto 51
      end if

      if (nclose > ndmax) nclose = ndmax
    end if

    call srchnd(ix, iy, iz)

    if (idbg >= 0) then
      write(ldbg, *) 'There are ncnode=', ncnode, &
                     ' in the search radius for grid ', in_local, index_local
    end if

    ! FIND DATA IN VOLUME NEIGHBOURHOOD
    call nhoodvol(ix, iy, iz, xx, yy, zz, index_local)

    if (read_volnh == 0) then
      write(97) (nusev)
      write(97) (usev(i), i=1, nusev)
      write(96) (ncnode)
      write(96) (cnodex(i), i=1, ncnode)
      write(96) (cnodey(i), i=1, ncnode)
      write(96) (cnodez(i), i=1, ncnode)
      write(96) (cnodev(i), i=1, ncnode)
      write(96) (cnodeindex(i), i=1, ncnode)
    end if

    if (read_volnh == 1) then
      read(97) nusev
      read(97) (usev(i), i=1, nusev)
      read(96) ncnode
      read(96) (cnodex(i), i=1, ncnode)
      read(96) (cnodey(i), i=1, ncnode)
      read(96) (cnodez(i), i=1, ncnode)
      read(96) (cnodev(i), i=1, ncnode)
      read(96) (cnodeindex(i), i=1, ncnode)
    end if

    ! Calculate the conditional mean and standard deviation
    if (ktype == 2) then
      gmean = lvm(index_local)
    else
      gmean = skgmean
    end if

51  continue

    ! Double check for not enough data with search radius
    if (index_local <= 5) then
      write(*,*) 'DEBUG: Node', index_local, ' nclose=', nclose, ' ncnode=', ncnode, ' nusev=', nusev, ' gmean=', gmean
    end if

    if ((nclose + ncnode + nusev) < 1) then
      if (index_local <= 5 .or. idbg > 1) then
        write(*,*) ' __WARNING: Node', index_local, ' no neighboring data - using global mean/var', gmean
      end if
      cmean = gmean
      cstdev = sqrt(gvar)
    else
      if (idbg >= 3) then
        write(ldbg, *) 'cmean=', cmean, 'cstdev=', cstdev
      end if

      ! Perform the kriging
      lktype = ktype
      if (ktype == 1 .and. (nclose + ncnode) < 4) lktype = 0

      call krige_volume(ix, iy, iz, xx, yy, zz, lktype, &
                        gmean, cmean, cstdev, index_local)
    end if

    if (idbg > 3) then
      write(*, *) 'SIM in=', in_local, ' RESULT index=', &
                  order(in_local), ' cmean=', cmean, ' cstdev=', cstdev
    end if

    ! Draw a value from the distribution
    p = acorni(idum)

    if (p >= pkr) then
      if (doestimation == 0) then
        sim(index_local) = simu(cmean, cstdev)
      end if
      sim_mean(index_local) = cmean
      sim_std(index_local) = cstdev
      if (index_local <= 5 .and. idbg >= 0) then
        write(*,*) 'DEBUG: Set sim_mean(', index_local, ')=', cmean
      end if
    else
      if (idbg > 0) write(*, *) 'PKR PKR', pkr
      sim(index_local) = cmean
    end if

  end do  ! END MAIN LOOP OVER NODES

  if (idbg >= 0) then
    write(*,*) 'DEBUG: After main loop, sim_mean(1:5)=', sim_mean(1:5)
  end if

  if (doestimation == 1) then
    do i = 1, nxyz
      sim(i) = sim_mean(i)
      write(lout_mean, 87) sim_mean(i), sim_std(i) * sim_std(i)
87    format(f19.8, f19.8)
    end do
  end if

  ! Write estimated volume average to screen
  if (idbg > 1) then
    if ((icond == 1) .or. (icond == 3)) then
      write(*, 89)
      write(*, *) 'VOLUME AVERAGE ESTIMATES : '
      sumderr = 0
      sumerr = 0
      do ivol_local = 1, nvol
        vobs = 0
        do id = 1, ndatainvol(ivol_local)
          call getindx(nx, xmn, xsiz, volx(ivol_local, id), ix1, testind)
          call getindx(ny, ymn, ysiz, voly(ivol_local, id), iy1, testind)
          call getindx(nz, zmn, zsiz, volz(ivol_local, id), iz1, testind)
          ind = ix1 + (iy1 - 1) * nx + (iz1 - 1) * nxy
          vobs = vobs + voll(ivol_local, id) * sim(ind)
        end do
        derr = 100 * (volobs(ivol_local) - vobs) / (volobs(ivol_local))
        sumderr = sumderr + abs(derr)
        sumerr = sumerr + abs((volobs(ivol_local) - vobs))
        write(*, 88) ivol_local, vobs, volobs(ivol_local), derr
88      format(' Volume ', i3, ': obs_sim=', f8.3, &
               ' obs_vol=', f8.3, ' diff=', f8.3, '%')
      end do

      sumderr = sumderr / nvol
      sumerr = sumerr / nvol
      if (idbg > 0) write(*, 89) sumderr, 100 * sumerr / gmean
89    format(' Mean Error ', f5.3, ': MeanRelErr=', f5.3, '%')
    end if
  end if

  if (idbg > 2) then
    print *, 'negative is ', neg, ', nsmall0 is ', &
             nsmall0, ', small is ', nsmall, ', nlarge is ', nlarge
  end if

  ! In the case when no data assigned to grid, reassign data values
  if (sstrat == 0) then
    do id = 1, nd
      call getindx(nx, xmn, xsiz, x(id), ix, testind)
      call getindx(ny, ymn, ysiz, y(id), iy, testind)
      call getindx(nz, zmn, zsiz, z(id), iz, testind)
      xx = xmn + real(ix - 1) * xsiz
      yy = ymn + real(iy - 1) * ysiz
      zz = zmn + real(iz - 1) * zsiz
      ind = ix + (iy - 1) * nx + (iz - 1) * nxy
      test = abs(xx - x(id)) + abs(yy - y(id)) + abs(zz - z(id))
      if (test <= TINY) sim(ind) = vr(id)
    end do
  end if

  ! Write results
  ne = 0
  av = 0.0
  ss = 0.0
  do ind = 1, nxyz
    simval = sim(ind)
    ne = ne + 1
    av = av + simval
    ss = ss + simval * simval
    write(lout, '(f19.10)') simval
  end do

  av = av / max(real(ne), 1.0)
  ss = (ss / max(real(ne), 1.0)) - av * av

  if (idbg > -1) then
    write(ldbg, 112) isim, ne, av, ss
    write(*, 112) isim, ne, av, ss
112 format(/, ' Realization ', i3, ': number   = ', i8, /, &
           '                  mean     = ', f12.4, &
           ' (close to global mean)', /, &
           '                  variance = ', f12.4, &
           ' (close to global variance)', /)
  end if

  return

end subroutine visim
