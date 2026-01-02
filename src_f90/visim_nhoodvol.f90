subroutine nhoodvol(ix, iy, iz, xx, yy, zz, sim_index)
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
!               SELECT NEIGHBORHOOD FOR VOLUMES
!               *******************************
!
! INPUT VARIABLES:
!
!   ix,iy,iz        index of the point currently being simulated
!   xx,yy,zz        location of the point currently being simulated
!   sim_index       index of point being simulated
!
!   nusevols [integer] : Use a maximum of 'nusevols' (on when musevols=2)
!
!   musevols=
!     [0] : use all  volumes
!     [1] : use only volumes sensitive to the current point, with a
!           Cov(Point,Vol)/gvar>accept_frac
!     [2] Use MAX      N data (sort by Cov(PointToVol)
!     [3] Use EXACTLY  N data (sort by Cov(PointToVol)
!
!
! OUTPUT VARIABLES:
!   nclosevol
!
!
!
! ORIGINAL: Thomas Mejer Hansen, Yongshe Liu  DATE: June, 2004
! Update to account for correlated data errors : TMH, 06/2007.
!-----------------------------------------------------------------------
  use visim_params_mod
  use visim_grid_mod
  use visim_volume_mod
  use visim_covariance_mod
  use visim_search_mod
  implicit none

  ! Arguments
  integer, intent(in) :: ix, iy, iz, sim_index
  real, intent(in) :: xx, yy, zz

  ! Local variables
  integer :: volindex, vol
  integer :: nsensvol, sensvol(maxvols_dim), volok(maxvols_dim)
  integer :: temp(maxvols_dim), temp2(maxvols_dim)
  real :: covvol(maxvols_dim)
  integer :: idata, nvolok
  integer :: nclosevol
  real :: covsum, cov
  integer :: ivol1, ivol2, inhood, i, j, ivol, isensvol
  integer :: nusevols_temp
  integer :: useCd, dinnhood
  integer :: c, d, e, f, g, h  ! Dummy variables for sortem

  ! External GSLIB functions
  external :: sortem, cov_data2vol

  nusevols_temp = nusevols

  if (idbg > 10) then
    write(*, *) 'VOLNHOOD : musevols=', musevols, &
                ' nusevols=', nusevols
  end if

  ! musevol=0, USE ALL AVAILABLE DATA ALL THE TIME
  if (musevols == 0) then
    nusev = nvol
    do ivol = 1, nvol
      usev(ivol) = ivol
    end do
    return
  end if

  if (musevols >= 1) then
    nusev = 0
    if (densitypr > 0) then
      ! IF random path is NOT 'independent' we can simply look
      ! for volume data that contain the current point
      ! use only volume data through simulation point
      do ivol = 1, nvol
        do idata = 1, ndatainvol(ivol)
          volindex = voli(ivol, idata)
          if (volindex == sim_index) then
            nusev = nusev + 1
            usev(nusev) = ivol
          end if
        end do
      end do
    else
      ! USE ALL RAY DATA WITH A SIGNIFICANT CORRELATION
      do ivol = 1, nvol
        call cov_data2vol(sim_index, xx, yy, zz, ivol, cov)
        if (cov >= (accept_fract * gvar)) then
          nusev = nusev + 1
          usev(nusev) = ivol
        end if
      end do
    end if
  else
    ! use all volume data all the time
    nusev = nvol
    do i = 1, nusev
      usev(i) = i
    end do
  end if

  ! CALCULATE THE COVARIANCE BETWEEN THE POINT TO BE SIMULATED AND
  ! ALL THE VOLUME AVERAGES. THEN CHOOSE VOLUME AVERAGES
  ! ABOVE SOME THRESHOLD.
  ! ONLY DO THIS IF WE ARE ACTUALLY AT A LOCATION
  ! WHERE A VOLUME AVERAGE IS PASSING THROUGH

  if ((musevols >= 2) .and. (nusev > 0)) then
    nusev = 0
    do ivol = 1, nvol
      covsum = 0
      call cov_data2vol(sim_index, xx, yy, zz, ivol, covsum)
      temp(ivol) = ivol
      temp2(ivol) = ivol
      covvol(ivol) = -covsum
    end do

    ! SORT BY cov(point,vol)
    call sortem(1, nvol, covvol, 1, temp, c, d, e, f, g, h)

    if (nvol <= nusevols) then
      nusevols_temp = nvol
    else
      nusevols_temp = nusevols
    end if

    nusev = 0
    if (musevols == 2) then
      do ivol = 1, nusevols_temp
        if (abs(covvol(ivol)) > (accept_fract * gvar)) then
          nusev = nusev + 1
          usev(nusev) = temp(ivol)
        end if
      end do
    else
      do ivol = 1, nusevols_temp
        nusev = nusev + 1
        usev(nusev) = temp(ivol)
      end do
    end if
  end if

  ! make sure that simulated volumes are not used as volumes data
  ! volok is an array of size [1:nusevol] indicating whether a
  ! volume has already been been fully simulated. In that
  ! case it should be excluded to avoid a singular kriging system
  !
  ! This should be optimized using a lookup table for already simulated
  ! volumes -> No need to run through the volume once it has been established
  ! that is IS already simulated completely

  nvolok = 0
  do ivol = 1, nusev
    volok(ivol) = 0
    do idata = 1, ndatainvol(usev(ivol))
      volindex = voli(usev(ivol), idata)
      if (sim(volindex) <= UNEST) then
        volok(ivol) = 1
      end if
    end do
    if (volok(ivol) == 1) then
      nvolok = nvolok + 1
    end if
  end do

  ! FINALLY GO THROUGH THE VOLUMES AND DESELECT THE VOLUMES ALREADY
  ! SIMULATED AS INDICATED BY volok(ivol)=0

  if (nvolok /= nusev) then
    i = 0
    do ivol = 1, nusev
      if (volok(ivol) == 1) then
        i = i + 1
        usev(i) = usev(ivol)
      end if
    end do
    nusev = i
  end if

  ! NOW THE VOLUME AVERAGE DATA TO USE HAS BEEN FOUND ('usev' and 'nusev')

  ! SELECT WHICH PREVIOUSLY SIMULATED OR HARD DATA WITHIN VOLUME
  ! TO USE AS CONDITIONAL DATA

  ! FIRST FIND THE VOLUMES SENSITIVE TO THE SIMULATED POINT
  nsensvol = 0
  do ivol = 1, nusev
    do idata = 1, ndatainvol(usev(ivol))
      if (voli(usev(ivol), idata) == sim_index) then
        ! USE ALL PREVIOUSLY SIMULATED DATA ON RAY
        nsensvol = nsensvol + 1
        sensvol(nsensvol) = ivol
      end if
    end do
  end do

  useCd = 1

  if (musevols >= 4) then
    ! CONSIDER THE DATACOVARIANCE !!
    do i = 1, nusev
      do ivol = 1, nvol
        if (datacov(ivol, usev(i)) > 0) then
          ! CHECK IF VOLUME DATA IS ALREADY IN VOLHOOD
          inhood = 0
          do j = 1, nvol
            if (usev(j) == ivol) then
              inhood = 1
            end if
          end do

          if (inhood == 0) then
            nusev = nusev + 1
            usev(nusev) = ivol
          end if
        end if
      end do
    end do
  end if

  ! LOOP THROUGH SENSITIVE VOLUMES AND FIND DATA TO ADD
  ! TO THE SEARCH NEIGHBORHOOD

  nclosevol = 0
  do isensvol = 1, nsensvol
    ivol = usev(sensvol(isensvol))
    do idata = 1, ndatainvol(ivol)
      if (sim(voli(ivol, idata)) /= UNEST) then
        ! CHECK THAT THE DATA HAS NOT ALREADY BEEN INCLUDED IN THE NEIGHBORHOOD
        dinnhood = 0
        do i = 1, ncnode
          if (cnodeindex(i) == voli(ivol, idata)) then
            dinnhood = 1
          end if
        end do

        ! NOW ADD THE DATA TO THE PREV COND DATA IF
        ! IT IS NOT ALREADY ADDED
        if ((dinnhood == 0) .and. (ncnode < nodmax)) then
          nclosevol = nclosevol + 1
          ncnode = ncnode + 1

          cnodex(ncnode) = volx(ivol, idata)
          cnodey(ncnode) = voly(ivol, idata)
          cnodez(ncnode) = volz(ivol, idata)
          cnodev(ncnode) = sim(voli(ivol, idata))
          cnodeindex(ncnode) = voli(ivol, idata)

          if (ncnode == nodmax) then
            write(*, *) 'YOU REACHED MAX NUMBER OF NODES - ', &
                        'ncnode=', ncnode, ' nodmax=', nodmax
            write(*, *) 'Increase nodmax in parameter file'
          end if
        end if
      end if
    end do
  end do

  return

end subroutine nhoodvol
