subroutine rayrandpath(order_array)
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!                                                                      %
! Copyright (C) 1996, The Board of Trustees of the Leland Stanford    %
! Junior University.  All rights reserved.                            %
!                                                                      %
! Converted to Fortran 90 - 2026                                      %
!                                                                      %
!%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
!-----------------------------------------------------------------------
!  Descriptions:
!     We can define both random and sequential path for 1 ray using this subroutine
!     The random path are stored in the array called 'order'.
!     The random value and random path are written to a temporary output file for check.
!
!  parameters:
!
!      densitypr : Density priority : Give higher priority (sample early)
!                  to data points sensitive to larger volumes
!                  [2] : order by number of volumes at data
!                  [1] : order by sum of density at data
!                  [0] : Don't use density priority
!
!      shuffvol: [1] randomly shuffle volumes
!                [0] use volumes in the order they are read
!
!      shuffinvol : [0] sort by distance from source (AS READ)
!                   [1] shuffle within volume
!                   [2] shuffle within all volumes
!                       This means a) random point in any volume
!                             then b) random point outside volume
!                       This option overrides 'shuffvol'
!
!
! ORIGINAL: Yongshe Liu, Thomas Mejer Hansen   DATE: June, 2004
!-----------------------------------------------------------------------
  use visim_params_mod
  use visim_grid_mod
  use visim_volume_mod
  use visim_random_mod
  implicit none

  ! Arguments
  real, intent(inout) :: order_array(nxyz)

  ! Local variables
  integer :: ind, ix, iy, iz, nxy_local, j, k, nvp, i, ivol, idata
  real :: tempsim(nxyz), vvx(maxdinvol_dim)
  real :: simrest(nxyz)
  real :: svoll(nxyz), nvoll(nxyz)
  integer :: vorder(nxyz), ivoll(nxyz)
  real :: svoll2(nxyz), nvoll2(nxyz)
  integer :: varr(maxvols_dim)
  real :: tempvol(maxvols_dim)
  real :: p
  real*8 :: acorni
  integer :: c, d, e, f, g, h  ! Dummy variables for sortem
  logical :: testind
  character(len=80) :: tmpfl

  ! External GSLIB functions
  external :: sortem, getindx, acorni

  ! These next variables COULD be set in visim.par file
  ! but, since there is a clear benefit setting shuffinvol=2,
  ! this is chosen as default.
  ! The defaults are chosen here:

  shuffvol = 1
  shuffinvol = 2

  if (idbg > 0) then
    write(*, *) 'Random Path : densitypr=', densitypr, &
                '  shuffvol=', shuffvol, &
                '  shuffinvol=', shuffinvol
  end if

  nxy_local = nx * ny

  ! Classic independent path
  if (densitypr == 0) then
    p = real(acorni(idum))
    call sortem(1, nxyz, sim, 1, order_array, c, d, e, f, g, h)
    return
  end if

  ! SORT VOLUMES IF NEEDED
  if (shuffvol == 1) then
    do ivol = 1, nvol
      tempvol(ivol) = real(acorni(idum))
      varr(ivol) = ivol
    end do
    call sortem(1, nvol, tempvol, 1, varr, c, d, e, f, g, h)
  else
    ! ELSE DON'T SORT VOLUMES
    do ivol = 1, nvol
      varr(ivol) = ivol
    end do
  end if

  if (idbg > 3) then
    do ivol = 1, nvol
      write(*, *) 'varr(', ivol, ')=', varr(ivol)
    end do
  end if

  ! INITIALIZE THE SORT OF ALL THE POINTS
  ! ASSIGN A RANDOM VALUE BETWEEN 0 and 1 TO ALL DATA
  do i = 1, nxyz
    tempsim(i) = real(acorni(idum))
    order_array(i) = i
  end do

  ! the nvoll2 and svoll2 are only initialized since the sortem function
  ! alters the values of nvoll and svoll when called !

  ! APPLY DENSITY PRIORITY IF NEEDED
  nvp = 1
  if (densitypr > 1) then
    do ind = 1, nxyz
      svoll(nvp) = 0
      nvoll(nvp) = 0
      svoll2(nvp) = 0
      nvoll2(nvp) = 0
      do ivol = 1, nvol
        do idata = 1, ndatainvol(ivol)
          if (voli(ivol, idata) == ind) then
            svoll(nvp) = svoll(nvp) + voll(ivol, idata)
            nvoll(nvp) = nvoll(nvp) + 1
            nvoll2(nvp) = nvoll(nvp)
            svoll2(nvp) = svoll(nvp)
            ivoll(nvp) = ind
            vorder(nvp) = nvp
          end if
        end do
      end do
      ! ONLY CONSIDER THIS DATA IF MORE THAN ONE VOLUME GOES THROUGH IT
      if (nvoll(nvp) > 1) then
        if (idbg > -13) then
          ! write(*,*) 'nv(',ind,')=',svoll(nvp),nvoll(nvp),nvp
        end if
        nvp = nvp + 1
      end if
    end do
    nvp = nvp - 1

    ! NOW SORT THE nvp DATA USING EITHER OF TWO CRITERIA
    if (densitypr == 2) then
      ! SORT BY SUM OF DENSITY AT POINT
      if (idbg > 0) write(*, *) 'SORT BY DENSITY'
      call sortem(1, nvp, svoll, 1, vorder, c, d, e, f, g, h)
    else
      ! SORT BY NUMBER VOLUME DATA POINT
      if (idbg > 0) write(*, *) 'SORT BY NVOLS THROUGH POINT'
      call sortem(1, nvp, nvoll, 1, vorder, c, d, e, f, g, h)
    end if

    do i = 1, nvp
      if (densitypr == 2) then
        tempsim(ivoll(vorder(i))) = tempsim(ivoll(vorder(i))) - &
                                     (nvol + real(i) / 10000 + svoll2(vorder(i)))
      else
        tempsim(ivoll(vorder(i))) = tempsim(ivoll(vorder(i))) - &
                                     (nvol + real(i) / 10000 + nvoll2(vorder(i)))
      end if
    end do
  end if

  ! GET INDEX OF DATA IN VOLUME
  i = 0
  do ivol = 1, nvol
    do idata = 1, ndatainvol(varr(ivol))
      i = i + 1
      call getindx(nx, xmn, xsiz, volx(varr(ivol), idata), ix, testind)
      call getindx(ny, ymn, ysiz, voly(varr(ivol), idata), iy, testind)
      call getindx(nz, zmn, zsiz, volz(varr(ivol), idata), iz, testind)
      ind = ix + (iy - 1) * nx + (iz - 1) * nxy_local
      ! ONLY CHANGE THE TEMPSIM FOR THE INDEX IF NOT PREVIOUSLY SAMPLED
      if (tempsim(ind) > 0) then
        if (shuffinvol == 0) then
          tempsim(ind) = real(idata) / 10000 - (nvol - ivol + 1)
        else if (shuffinvol == 1) then
          tempsim(ind) = tempsim(ind) - (nvol - ivol + 1)
        else if (shuffinvol == 2) then
          tempsim(ind) = tempsim(ind) - 1
        end if
      else
        ! DO NOTHING
      end if
    end do
  end do

  ! SORT THE DATA
  call sortem(1, nxyz, tempsim, 1, order_array, c, d, e, f, g, h)

  return

end subroutine rayrandpath
