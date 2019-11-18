!===========================================================================
!===========================================================================
!This file is part of ElVibRot.
!
!    ElVibRot is free software: you can redistribute it and/or modify
!    it under the terms of the GNU Lesser General Public License as published by
!    the Free Software Foundation, either version 3 of the License, or
!    (at your option) any later version.
!
!    ElVibRot is distributed in the hope that it will be useful,
!    but WITHOUT ANY WARRANTY; without even the implied warranty of
!    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!    GNU Lesser General Public License for more details.
!
!    You should have received a copy of the GNU Lesser General Public License
!    along with ElVibRot.  If not, see <http://www.gnu.org/licenses/>.
!
!    Copyright 2015  David Lauvergnat
!      with contributions of Mamadou Ndong, Josep Maria Luis
!
!    ElVibRot includes:
!        - Tnum-Tana under the GNU LGPL3 license
!        - Somme subroutines of John Burkardt under GNU LGPL license
!             http://people.sc.fsu.edu/~jburkardt/
!        - Somme subroutines of SHTOOLS written by Mark A. Wieczorek under BSD license
!             http://shtools.ipgp.fr
!===========================================================================
!===========================================================================


MODULE mod_OpPsi_SG4

PRIVATE
PUBLIC :: sub_OpPsi_FOR_SGtype4,sub_TabOpPsi_FOR_SGtype4
PUBLIC :: sub_TabOpPsi_OF_ONEDP_FOR_SGtype4
PUBLIC :: sub_TabOpPsi_OF_ONEGDP_WithOp_FOR_SGtype4

CONTAINS

 SUBROUTINE sub_OpPsi_FOR_SGtype4(Psi,OpPsi,para_Op)

 USE mod_system
!$ USE omp_lib, only : OMP_GET_THREAD_NUM
 USE mod_nDindex
 USE mod_Coord_KEO,                ONLY : zmatrix

 USE mod_basis_set_alloc,          ONLY : basis
 USE mod_basis_RCVec_SGType4,      ONLY : TypeRVec,dealloc_TypeRVec
 USE mod_basis_BtoG_GtoB_SGType4,  ONLY : tabPackedBasis_TO_tabR_AT_iG, &
                                          tabR_AT_iG_TO_tabPackedBasis

 USE mod_psi_set_alloc,            ONLY : param_psi,ecri_psi,assignment (=)

 USE mod_SetOp,                    ONLY : param_Op,write_param_Op
 USE mod_MPI
 IMPLICIT NONE

 TYPE (param_psi), intent(in)      :: Psi
 TYPE (param_psi), intent(inout)   :: OpPsi

 TYPE (param_Op),  intent(inout)   :: para_Op

 ! local variables
 TYPE (zmatrix), pointer :: mole
 TYPE (basis),   pointer :: BasisnD

 TYPE (TypeRVec)         :: PsiR

 integer                :: ib,i,iG,iiG,nb_thread,ith,iterm00
 integer, allocatable   :: tab_l(:)
 logical                :: not_init

 !----- for debuging ----------------------------------------------
 character (len=*), parameter :: name_sub='sub_OpPsi_FOR_SGtype4'
 logical, parameter :: debug = .FALSE.
 !logical, parameter :: debug = .TRUE.
 !-----------------------------------------------------------------
 IF (debug) THEN
   write(out_unitp,*) 'BEGINNING ',name_sub
   write(out_unitp,*) 'nb_bie,nb_baie',para_Op%nb_bie,para_Op%nb_baie
   write(out_unitp,*) 'nb_act1',para_Op%mole%nb_act1
   write(out_unitp,*) 'nb_var',para_Op%mole%nb_var
   !CALL flush_perso(out_unitp)
   !CALL write_param_Op(para_Op)
   write(out_unitp,*)
   write(out_unitp,*) 'PsiBasisRep'
   write(out_unitp,*) 'Psi%RvecB',Psi%RvecB
   CALL flush_perso(out_unitp)
 END IF
 !-----------------------------------------------------------------
  !CALL Check_mem()

  mole    => para_Op%mole
  BasisnD => para_Op%BasisnD

  IF (Psi%cplx) STOP 'cplx'
  IF (para_Op%nb_bie /= 1) STOP 'nb_bie /= 1 in sub_OpPsi_FOR_SGtype4'

  IF (SG4_omp == 0) THEN
    nb_thread = 1
  ELSE
    nb_thread = SG4_maxth
  END IF


 nb_mult_OpPsi   = 0
 OpPsi           = Psi ! for the allocation. It has to be changed!
 OpPsi%RvecB(:)  = ZERO

 IF (print_level > 0 .AND. BasisnD%para_SGType2%nb_SG > 10**4 ) THEN
   write(out_unitp,'(a)')              'OpPsi SG4 (%): [-10-20-30-40-50-60-70-80-90-100]'
   write(out_unitp,'(a)',ADVANCE='no') 'OpPsi SG4 (%): ['
   CALL flush_perso(out_unitp)
 END IF

 IF (OpPsi_omp == 0) THEN
   DO iG=1,BasisnD%para_SGType2%nb_SG

     !write(6,*) 'iG',iG
     !transfert part of the psi%RvecB(:) to PsiR%V
     CALL tabPackedBasis_TO_tabR_AT_iG(PsiR%V,psi%RvecB,    &
                                         iG,BasisnD%para_SGType2)
     !write(6,*) 'iG,PsiR',iG,PsiR%V

     CALL sub_OpPsi_OF_ONEDP_FOR_SGtype4_ompGrid(PsiR,iG,para_Op)

     !transfert back, PsiR%V (HPsi) to the psi%RvecB(:)
     CALL tabR_AT_iG_TO_tabPackedBasis(OpPsi%RvecB,PsiR%V,  &
                     iG,BasisnD%para_SGType2,BasisnD%WeightSG(iG))

     !deallocate PsiR
     CALL dealloc_TypeRVec(PsiR)


     IF (print_level > 0  .AND. BasisnD%para_SGType2%nb_SG > 10**4 .AND. &
         mod(iG,max(1,BasisnD%para_SGType2%nb_SG/10)) == 0 .AND. MPI_id==0) THEN
       write(out_unitp,'(a)',ADVANCE='no') '---'
       CALL flush_perso(out_unitp)
     END IF

     !write(6,*) 'iG done:',iG ; flush(6)
   END DO
 ELSE

   !to be sure to have the correct number of threads
   nb_thread = BasisnD%para_SGType2%nb_threads

   !$OMP parallel                                                &
   !$OMP default(none)                                           &
   !$OMP shared(Psi,OpPsi)                                       &
   !$OMP shared(para_Op,BasisnD,print_level,out_unitp)           &
   !$OMP private(iG,iiG,tab_l,PsiR,ith)                          &
   !$OMP num_threads(BasisnD%para_SGType2%nb_threads)

   !--------------------------------------------------------------
   !-- For the initialization of tab_l(:) and the use of ADD_ONE_TO_nDindex in the parallel loop
   CALL alloc_NParray(tab_l,(/ BasisnD%para_SGType2%nDind_SmolyakRep%ndim /),'tabl_l',name_sub)

   ith = 0
   !$ ith = OMP_GET_THREAD_NUM()
   tab_l(:) = BasisnD%para_SGType2%nDval_init(:,ith+1)
   !--------------------------------------------------------------

   ! we are not using the parallel do, to be able to use the correct initialized tab_l with nDval_init
   DO iG=BasisnD%para_SGType2%iG_th(ith+1),BasisnD%para_SGType2%fG_th(ith+1)

     CALL ADD_ONE_TO_nDindex(BasisnD%para_SGType2%nDind_SmolyakRep,tab_l,iG=iG)

     !write(6,*) 'iG',iG ; flush(6)
     !transfert part of the psi%RvecB(:) to PsiR%V
     CALL tabPackedBasis_TO_tabR_AT_iG(PsiR%V,psi%RvecB,iG,BasisnD%para_SGType2)
     !write(6,*) 'iG,PsiR',iG,PsiR%V ; flush(6)

     CALL sub_OpPsi_OF_ONEDP_FOR_SGtype4(PsiR,iG,tab_l,para_Op)

     !transfert back, PsiR%V (HPsi) to the psi%RvecB(:)
     CALL tabR_AT_iG_TO_tabPackedBasis(OpPsi%RvecB,PsiR%V,              &
                           iG,BasisnD%para_SGType2,BasisnD%WeightSG(iG))

     !deallocate PsiR(:)
     CALL dealloc_TypeRVec(PsiR)


     IF (print_level > 0  .AND. BasisnD%para_SGType2%nb_SG > 10**4 .AND. &
         mod(iG,max(1,BasisnD%para_SGType2%nb_SG/10)) == 0 .AND. MPI_id==0) THEN
       write(out_unitp,'(a)',ADVANCE='no') '---'
       CALL flush_perso(out_unitp)
     END IF

     !write(6,*) 'iG done:',iG ; flush(6)
   END DO
   CALL dealloc_NParray(tab_l,'tabl_l',name_sub)
  !$OMP   END PARALLEL
END IF

 IF (print_level > 0 .AND. BasisnD%para_SGType2%nb_SG > 10**4) THEN
   write(out_unitp,'(a)',ADVANCE='yes') '-]'
 END IF
 CALL flush_perso(out_unitp)

 iterm00 = para_Op%derive_term_TO_iterm(0,0)
 IF (associated(para_Op%OpGrid)) THEN
   para_Op%OpGrid(iterm00)%para_FileGrid%Save_MemGrid_done =            &
                     para_Op%OpGrid(iterm00)%para_FileGrid%Save_MemGrid
   para_Op%OpGrid(iterm00)%para_FileGrid%Save_FileGrid_done =           &
                     para_Op%OpGrid(iterm00)%para_FileGrid%Save_FileGrid
 END IF

!-----------------------------------------------------------
 IF (debug) THEN
   write(out_unitp,*) 'OpPsiBasisRep'
   write(out_unitp,*) 'OpPsi%RvecB',OpPsi%RvecB
   write(out_unitp,*)
   write(out_unitp,*) 'END ',name_sub
 END IF
!-----------------------------------------------------------

  END SUBROUTINE sub_OpPsi_FOR_SGtype4

 SUBROUTINE sub_OpPsi_OF_ONEDP_FOR_SGtype4(PsiR,iG,tab_l,para_Op)
 USE mod_system
!$ USE omp_lib, only : OMP_GET_THREAD_NUM
 USE mod_nDindex

 USE mod_Coord_KEO,               ONLY : zmatrix, get_Qact, get_d0GG

 USE mod_basis_set_alloc,         ONLY : basis
 USE mod_basis,                   ONLY : Rec_Qact_SG4_with_Tab_iq
 USE mod_basis_RCVec_SGType4,     ONLY : TypeRVec
 USE mod_basis_BtoG_GtoB_SGType4, ONLY : BDP_TO_GDP_OF_SmolyakRep,    &
                                            GDP_TO_BDP_OF_SmolyakRep, &
                                        DerivOp_TO_RDP_OF_SmolaykRep, &
                                        tabR2grid_TO_tabR1_AT_iG,     &
                                        getbis_tab_nq,getbis_tab_nb
 USE mod_SetOp,                    ONLY : param_Op,write_param_Op
 IMPLICIT NONE

 TYPE (TypeRVec),                    intent(inout)    :: PsiR
 integer,                            intent(in)       :: iG,tab_l(:)

 TYPE (param_Op),                    intent(inout)       :: para_Op

 !local variables
 TYPE (zmatrix), pointer :: mole
 TYPE(basis),    pointer :: BasisnD

 integer :: iq,nb,nq,i,j,D
 integer :: ib0,jb0,nb0,iqi,iqf,jqi,jqf

 integer                               :: derive_termQdyn(2)

 real (kind=Rkind),  allocatable       :: V(:,:,:)
 real (kind=Rkind),  allocatable       :: Qact(:)
 real (kind=Rkind),  allocatable       :: GGiq(:,:,:)
 real (kind=Rkind),  allocatable       :: sqRhoOVERJac(:),Jac(:)
 real (kind=Rkind)                     :: Rho

 real (kind=Rkind),  allocatable       :: PsiRj(:,:),PsiRi(:),OpPsiR(:)
 real (kind=Rkind),  allocatable       :: VPsi(:,:) ! size(nq,nb0)

 integer,            allocatable       :: tab_nq(:)
 integer,            allocatable       :: tab_nb(:)
 integer,            allocatable       :: tab_iq(:)
 integer :: iterm00
 integer :: err_sub


 !----- for debuging ----------------------------------------------
 integer :: err_mem,memory
 character (len=*), parameter :: name_sub='sub_OpPsi_OF_ONEDP_FOR_SGtype4'
 logical, parameter :: debug = .FALSE.
 !logical, parameter :: debug = .TRUE.
 !-----------------------------------------------------------------
 IF (debug) THEN
   write(out_unitp,*) 'BEGINNING ',name_sub
   write(out_unitp,*) 'nb_bie,nb_baie',para_Op%nb_bie,para_Op%nb_baie
   write(out_unitp,*) 'nb_act1',para_Op%mole%nb_act1
   write(out_unitp,*) 'nb_var',para_Op%mole%nb_var
   CALL flush_perso(out_unitp)
 END IF
 !-----------------------------------------------------------------

  !write(6,*) '================================' ; flush(6)
  !write(6,*) '============ START =============' ; flush(6)

  mole    => para_Op%mole
  BasisnD => para_Op%BasisnD

 D = size(tab_l)

 CALL alloc_NParray(Qact,(/mole%nb_var/),'Qact',name_sub)
 CALL alloc_NParray(tab_nb,(/ D /),'tab_nb',name_sub)
 CALL alloc_NParray(tab_nq,(/ D /),'tab_nq',name_sub)
 CALL alloc_NParray(tab_iq,(/ D /),'tab_iq',name_sub)

 tab_nq(:) = getbis_tab_nq(tab_l,BasisnD%tab_basisPrimSG)
 tab_nb(:) = getbis_tab_nb(tab_l,BasisnD%tab_basisPrimSG)


 nb  = BasisnD%para_SGType2%tab_nb_OF_SRep(iG)
 nq  = BasisnD%para_SGType2%tab_nq_OF_SRep(iG)
 nb0 = BasisnD%para_SGType2%nb0

 CALL alloc_NParray(PsiRj,(/ nq,mole%nb_act1 /),'PsiRj',       name_sub)
 CALL alloc_NParray(PsiRi,       (/ nq /),      'PsiRi',       name_sub)


 CALL get_OpGrid_type10_OF_ONEDP_FOR_SG4(iG,tab_l,para_Op,V,GGiq,sqRhoOVERJac,Jac)

 !write(6,*) ' GGiq:',GGiq
 !write(6,*) ' Jac :',Jac
 !write(6,*) ' sqRhoOVERJac :',sqRhoOVERJac
 !write(6,*) 'd0GG ... done' ; flush(6)
 CALL alloc_NParray(OpPsiR,(/nq/),'OpPsiR',name_sub)

 !write(6,*) ' V Basis of PsiR :',PsiR%V

 ! partial B to G
 CALL BDP_TO_GDP_OF_SmolyakRep(PsiR%V,BasisnD%tab_basisPrimSG,        &
                                 tab_l,tab_nq,tab_nb,nb0)
 ! now PsiR is on the grid
 !write(6,*) ' R Grid of PsiR :',PsiR%V
 !write(6,*) ' R Grid of PsiR : done',OMP_GET_THREAD_NUM() ; flush(6)

 ! VPsi calculation, it has to be done before because V is not diagonal
 CALL alloc_NParray(VPsi,(/nq,nb0/),'VPsi',name_sub)
 VPsi(:,:) = ZERO
 DO ib0=1,nb0
   jqi = 1
   jqf = nq
   DO jb0=1,nb0
     VPsi(:,ib0) = VPsi(:,ib0) + V(:,ib0,jb0) * PsiR%V(jqi:jqf)
     jqi = jqf+1
     jqf = jqf+nq
   END DO
 END DO

 iqi = 1
 iqf = nq
 DO ib0=1,nb0

   ! multiplication by sqRhoOVERJac
   PsiR%V(iqi:iqf) = PsiR%V(iqi:iqf) * sqRhoOVERJac(:)

   !write(6,*) ' R*sq Grid of PsiR :',PsiR%V
   !write(6,*) ' R*sq ... Grid of PsiR : done',OMP_GET_THREAD_NUM() ; flush(6)


   ! derivative with respect to Qj
   DO j=1,mole%nb_act1
     derive_termQdyn(:) = (/ mole%liste_QactTOQsym(j),0 /)

     PsiRj(:,j) = PsiR%V(iqi:iqf)
     CALL DerivOp_TO_RDP_OF_SmolaykRep(PsiRj(:,j),BasisnD%tab_basisPrimSG, &
                                         tab_l,tab_nq,derive_termQdyn)

     !write(6,*) 'dQj Grid of PsiR',j,PsiRj(:,j) ; flush(6)
   END DO
   !write(6,*) ' dQj R*sq ... Grid of PsiR : done',OMP_GET_THREAD_NUM() ; flush(6)

   OpPsiR(:) = ZERO
   DO i=1,mole%nb_act1

     PsiRi(:) = ZERO
     DO j=1,mole%nb_act1
       PsiRi(:) = PsiRi(:) + GGiq(:,j,i) * PsiRj(:,j)
     END DO
     PsiRi(:) = PsiRi(:) * Jac(:)
     !write(6,*) ' Jac Gij* ... Grid of SRep : done',iG,i,OMP_GET_THREAD_NUM() ; flush(6)

     derive_termQdyn(:) = (/ mole%liste_QactTOQsym(i),0 /)

     CALL DerivOp_TO_RDP_OF_SmolaykRep(PsiRi(:),BasisnD%tab_basisPrimSG,&
                                         tab_l,tab_nq,derive_termQdyn)

     !write(6,*) 'shape OpPsiR,PsiRi ',shape(OpPsiR),shape(PsiRi)
     !write(6,*) 'DerivOp_TO_RDP_OF_SmolaykRep : done',OMP_GET_THREAD_NUM() ; flush(6)

     OpPsiR(:) = OpPsiR(:) + PsiRi(:)
   END DO

   !write(6,*) ' dQi Jac Gij* ... Grid of PsiR : done',OMP_GET_THREAD_NUM() ; flush(6)

   OpPsiR(:) =   -HALF*OpPsiR(:) / ( Jac(:)*sqRhoOVERJac(:) ) + VPsi(:,ib0)
   !write(6,*) ' OpPsiR Grid of PsiR',OpPsiR
   !write(6,*) ' OpPsiR Grid of PsiR : done',OMP_GET_THREAD_NUM() ; flush(6)

   !tranfert OpPsiR (on the grid) to PsiR
   PsiR%V(iqi:iqf) = OpPsiR(:)

   iqi = iqf+1
   iqf = iqf+nq
 END DO

 IF (allocated(OpPsiR)) CALL dealloc_NParray(OpPsiR,'OpPsiR', name_sub)
 IF (allocated(VPsi))   CALL dealloc_NParray(VPsi,  'VPsi',   name_sub)

 CALL GDP_TO_BDP_OF_SmolyakRep(PsiR%V,BasisnD%tab_basisPrimSG,&
                               tab_l,tab_nq,tab_nb,nb0)
 ! now PsiR%V is on the Basis
 !write(6,*) ' V Basis of OpPsiR :',PsiR%V

 IF (allocated(PsiRi))        CALL dealloc_NParray(PsiRi,       'PsiRi',       name_sub)
 IF (allocated(PsiRj))        CALL dealloc_NParray(PsiRj,       'PsiRj',       name_sub)
 IF (allocated(GGiq))         CALL dealloc_NParray(GGiq,        'GGiq',        name_sub)
 IF (allocated(tab_nb))       CALL dealloc_NParray(tab_nb,      'tab_nb',      name_sub)
 IF (allocated(tab_nq))       CALL dealloc_NParray(tab_nq,      'tab_nq',      name_sub)
 IF (allocated(tab_iq))       CALL dealloc_NParray(tab_iq,      'tab_iq',      name_sub)
 IF (allocated(Qact))         CALL dealloc_NParray(Qact,        'Qact',        name_sub)
 IF (allocated(sqRhoOVERJac)) CALL dealloc_NParray(sqRhoOVERJac,'sqRhoOVERJac',name_sub)
 IF (allocated(Jac))          CALL dealloc_NParray(Jac,         'Jac',         name_sub)
 IF (allocated(V))            CALL dealloc_NParray(V,           'V',           name_sub)

 !write(6,*) '============ END ===============' ; flush(6)
 !write(6,*) '================================' ; flush(6)

 !-----------------------------------------------------------
 IF (debug) THEN
   write(out_unitp,*) 'END ',name_sub
   CALL flush_perso(out_unitp)
 END IF
 !-----------------------------------------------------------
 !CALL UnCheck_mem() ; stop
 END SUBROUTINE sub_OpPsi_OF_ONEDP_FOR_SGtype4
  SUBROUTINE sub_OpPsi_OF_ONEDP_FOR_SGtype4_ompGrid(PsiR,iG,para_Op)
  USE mod_system
  USE mod_nDindex

  USE mod_Coord_KEO,               ONLY : zmatrix, get_Qact, get_d0GG

  USE mod_basis_set_alloc,         ONLY : basis
  USE mod_basis,                   ONLY : Rec_Qact_SG4
  USE mod_basis_BtoG_GtoB_SGType4, ONLY : TypeRVec,                     &
                     BDP_TO_GDP_OF_SmolyakRep,GDP_TO_BDP_OF_SmolyakRep, &
                   DerivOp_TO_RDP_OF_SmolaykRep,tabR2grid_TO_tabR1_AT_iG,&
                     getbis_tab_nq,getbis_tab_nb
  USE mod_SetOp,                      ONLY : param_Op,write_param_Op

  IMPLICIT NONE

  TYPE (TypeRVec),                    intent(inout)    :: PsiR
  integer,                            intent(in)       :: iG
  TYPE (param_Op),                    intent(inout)    :: para_Op


  !local variables
  TYPE (zmatrix), pointer :: mole
  TYPE(basis),    pointer :: BasisnD

  integer :: iq,nb,nq,i,j,D

  integer                               :: derive_termQdyn(2)

  real (kind=Rkind),  allocatable       :: V(:,:,:)
  real (kind=Rkind),  allocatable       :: Qact(:)
  real (kind=Rkind),  allocatable       :: GGiq(:,:,:)
  TYPE (Type_nDindex)                   :: nDind_DPG    ! multidimensional DP index
  real (kind=Rkind),  allocatable       :: sqRhoOVERJac(:),Jac(:)
  real (kind=Rkind)                     :: Rho

  real (kind=Rkind),  allocatable       :: PsiRj(:,:),PsiRi(:),OpPsiR(:)
  real (kind=Rkind),  allocatable       :: VPsi(:,:) ! size(nq,nb0)

  integer,            allocatable       :: tab_nq(:)
  integer,            allocatable       :: tab_nb(:)
  integer,            allocatable       :: tab_l(:)
  integer :: iterm00
  integer :: ib0,jb0,nb0,iqi,iqf,jqi,jqf
  integer :: err_sub,nb_thread


  !----- for debuging ----------------------------------------------
  integer :: err_mem,memory
  character (len=*), parameter :: name_sub='sub_OpPsi_OF_ONEDP_FOR_SGtype4_ompGrid'
  logical, parameter :: debug = .FALSE.
  !logical, parameter :: debug = .TRUE.
  !-----------------------------------------------------------------
  IF (debug) THEN
    write(out_unitp,*) 'BEGINNING ',name_sub
    write(out_unitp,*) 'nb_bie,nb_baie',para_Op%nb_bie,para_Op%nb_baie
    write(out_unitp,*) 'nb_act1',para_Op%mole%nb_act1
    write(out_unitp,*) 'nb_var',para_Op%mole%nb_var
    CALL flush_perso(out_unitp)
  END IF
  !-----------------------------------------------------------------
  !CALL Check_mem()

   !write(6,*) '================================' ; flush(6)
   !write(6,*) '============ START =============' ; flush(6)


  IF (Grid_omp == 0 .AND. OpPsi_omp > 0) THEN
    nb_thread = 1
  ELSE
    nb_thread = Grid_maxth
  END IF


   mole    => para_Op%mole
   BasisnD => para_Op%BasisnD

   D   = size(BasisnD%para_SGType2%nDind_SmolyakRep%Tab_nDval,dim=1)

   CALL alloc_NParray(tab_l ,(/ D /),'tab_l', name_sub)
   CALL alloc_NParray(tab_nb,(/ D /),'tab_nb',name_sub)
   CALL alloc_NParray(tab_nq,(/ D /),'tab_nq',name_sub)

   tab_l(:)  = BasisnD%para_SGType2%nDind_SmolyakRep%Tab_nDval(:,iG)
   tab_nq(:) = getbis_tab_nq(tab_l,BasisnD%tab_basisPrimSG)
   tab_nb(:) = getbis_tab_nb(tab_l,BasisnD%tab_basisPrimSG)


   nb  = BasisnD%para_SGType2%tab_nb_OF_SRep(iG) ! because PsiR is in basis Rep
   nq  = BasisnD%para_SGType2%tab_nq_OF_SRep(iG)
   nb0 = BasisnD%para_SGType2%nb0

   CALL alloc_NParray(PsiRj,(/ nq,mole%nb_act1 /),'PsiRj',       name_sub)
   CALL alloc_NParray(PsiRi,       (/ nq /),      'PsiRi',       name_sub)
   CALL alloc_NParray(sqRhoOVERJac,(/ nq /),      'sqRhoOVERJac',name_sub)
   CALL alloc_NParray(Jac,         (/ nq /),      'Jac',         name_sub)

   !transfert part of the potential
   CALL get_OpGrid_type0_OF_ONEDP_FOR_SG4(iG,tab_l,para_Op,V)


   ! G calculation
   CALL alloc_NParray(GGiq,(/nq,mole%nb_act1,mole%nb_act1/),'GGiq',name_sub)
   CALL init_nDindexPrim(nDind_DPG,BasisnD%nb_basis,tab_nq,type_OF_nDindex=-1)

   !$OMP parallel                                               &
   !$OMP default(none)                                          &
   !$OMP shared(mole,BasisnD,para_Op,nq,tab_l,nDind_DPG,iG)     &
   !$OMP shared(sqRhoOVERJac,Jac,GGiq)                          &
   !$OMP private(iq,Qact,err_sub,Rho)                           &
   !$OMP num_threads(nb_thread)
   CALL alloc_NParray(Qact,(/mole%nb_var/),'Qact',name_sub)
   !$OMP   DO SCHEDULE(STATIC)
   DO iq=1,nq
     CALL get_Qact(Qact,mole%ActiveTransfo) ! rigid, flexible coordinates
     CALL Rec_Qact_SG4(Qact,BasisnD%tab_basisPrimSG,tab_l,nDind_DPG,iq,mole,err_sub)

     CALL get_d0GG(Qact,para_Op%para_Tnum,mole,d0GG=GGiq(iq,:,:),        &
                                         def=.TRUE.,Jac=Jac(iq),Rho=Rho)
     sqRhoOVERJac(iq) = sqrt(Rho/Jac(iq))

   END DO
   !$OMP   END DO
   CALL dealloc_NParray(Qact,'Qact',name_sub)
   !$OMP   END PARALLEL

   CALL dealloc_nDindex(nDind_DPG)

   CALL alloc_NParray(OpPsiR,(/nq/),'OpPsiR',name_sub)

   ! partial B to G
   CALL BDP_TO_GDP_OF_SmolyakRep(PsiR%V,BasisnD%tab_basisPrimSG,  &
                                 tab_l,tab_nq,tab_nb,nb0)
   ! now PsiR is on the grid
   !write(6,*) ' R Grid of PsiR :',PsiR%V
   !write(6,*) ' R Grid of PsiR : done',OMP_GET_THREAD_NUM() ; flush(6)

 ! VPsi calculation, it has to be done before because V is not diagonal
 CALL alloc_NParray(VPsi,(/nq,nb0/),'VPsi',name_sub)
 VPsi(:,:) = ZERO
 DO ib0=1,nb0
   jqi = 1
   jqf = nq
   DO jb0=1,nb0
     VPsi(:,ib0) = VPsi(:,ib0) + V(:,ib0,jb0) * PsiR%V(jqi:jqf)
     jqi = jqf+1
     jqf = jqf+nq
   END DO
 END DO

 iqi = 1
 iqf = nq
 DO ib0=1,nb0

   ! multiplication by sqRhoOVERJac
   PsiR%V(iqi:iqf) = PsiR%V(iqi:iqf) * sqRhoOVERJac(:)

   !write(6,*) ' R*sq Grid of PsiR :',PsiR
   !write(6,*) ' R*sq ... Grid of PsiR : done',OMP_GET_THREAD_NUM() ; flush(6)


   ! derivative with respect to Qj
   DO j=1,mole%nb_act1
     derive_termQdyn(:) = (/ mole%liste_QactTOQsym(j),0 /)

     PsiRj(:,j) = PsiR%V(iqi:iqf)
     CALL DerivOp_TO_RDP_OF_SmolaykRep(PsiRj(:,j),BasisnD%tab_basisPrimSG, &
                                         tab_l,tab_nq,derive_termQdyn)

     !write(6,*) 'dQj Grid of PsiR',j,PsiRj(:,j) ; flush(6)
   END DO
   !write(6,*) ' dQj R*sq ... Grid of PsiR : done',OMP_GET_THREAD_NUM() ; flush(6)

   OpPsiR(:) = ZERO
   DO i=1,mole%nb_act1

     PsiRi(:) = ZERO
     DO j=1,mole%nb_act1
       PsiRi(:) = PsiRi(:) + GGiq(:,j,i) * PsiRj(:,j)
     END DO
     PsiRi(:) = PsiRi(:) * Jac(:)
     !write(6,*) ' Jac Gij* ... Grid of SRep : done',iG,i,OMP_GET_THREAD_NUM() ; flush(6)

     derive_termQdyn(:) = (/ mole%liste_QactTOQsym(i),0 /)

     CALL DerivOp_TO_RDP_OF_SmolaykRep(PsiRi(:),BasisnD%tab_basisPrimSG,&
                                       tab_l,tab_nq,derive_termQdyn)

     OpPsiR(:) = OpPsiR(:) + PsiRi(:)

   END DO
   !write(6,*) ' dQi Jac Gij* ... Grid of PsiR : done',OMP_GET_THREAD_NUM() ; flush(6)

   OpPsiR(:) =   -HALF*OpPsiR(:) / ( Jac(:)*sqRhoOVERJac(:) ) + VPsi(:,ib0)
   !write(6,*) ' OpPsiR Grid of PsiR',OpPsiR
   !write(6,*) ' OpPsiR Grid of PsiR : done',OMP_GET_THREAD_NUM() ; flush(6)

   !tranfert OpPsiR (on the grid) to PsiR
   PsiR%V(iqi:iqf) = OpPsiR(:)

   iqi = iqf+1
   iqf = iqf+nq
 END DO


 IF (allocated(OpPsiR)) CALL dealloc_NParray(OpPsiR,'OpPsiR', name_sub)
 IF (allocated(VPsi))   CALL dealloc_NParray(VPsi,  'VPsi',   name_sub)


 CALL GDP_TO_BDP_OF_SmolyakRep(PsiR%V,BasisnD%tab_basisPrimSG,          &
                                   tab_l,tab_nq,tab_nb,nb0)
 ! now PsiR%V is on the Basis

 IF (allocated(PsiRi))        CALL dealloc_NParray(PsiRi,       'PsiRi',       name_sub)
 IF (allocated(PsiRj))        CALL dealloc_NParray(PsiRj,       'PsiRj',       name_sub)
 IF (allocated(GGiq))         CALL dealloc_NParray(GGiq,        'GGiq',        name_sub)
 IF (allocated(tab_nb))       CALL dealloc_NParray(tab_nb,      'tab_nb',      name_sub)
 IF (allocated(tab_nq))       CALL dealloc_NParray(tab_nq,      'tab_nq',      name_sub)
 IF (allocated(tab_l))        CALL dealloc_NParray(tab_l,       'tab_l',       name_sub)
 IF (allocated(sqRhoOVERJac)) CALL dealloc_NParray(sqRhoOVERJac,'sqRhoOVERJac',name_sub)
 IF (allocated(Jac))          CALL dealloc_NParray(Jac,         'Jac',         name_sub)
 IF (allocated(V))            CALL dealloc_NParray(V,           'V',           name_sub)

 !write(6,*) '============ END ===============' ; flush(6)
 !write(6,*) '================================' ; flush(6)

 !-----------------------------------------------------------
 IF (debug) THEN
   write(out_unitp,*) 'END ',name_sub
   CALL flush_perso(out_unitp)
 END IF
 !-----------------------------------------------------------
 !CALL UnCheck_mem() ; stop
 END SUBROUTINE sub_OpPsi_OF_ONEDP_FOR_SGtype4_ompGrid

!=======================================================================================
!> OpPsi is assigned in this routine with OpPsi%Vec=0 initially
!> after this subroutine, OpPsi will be ready
!======================================================================================= 
SUBROUTINE sub_TabOpPsi_FOR_SGtype4(Psi,OpPsi,para_Op)
  USE mod_system
  !$ USE omp_lib, only : OMP_GET_THREAD_NUM
  USE mod_nDindex

  USE mod_Coord_KEO,                ONLY : zmatrix
  USE mod_basis_set_alloc,          ONLY : basis
  USE mod_basis_BtoG_GtoB_SGType4,  ONLY : tabPackedBasis_TO_tabR_AT_iG, &
                                           tabR_AT_iG_TO_tabPackedBasis, &
#if(run_MPI)
                                           TypeRVec,dealloc_TypeRVec,    &
                                           PackedBasis_TO_tabR_index,    &
                                           tabR_TO_tabPackedBasis_MPI,   &
                                           tabPackedBasis_TO_tabR_MPI
#else
                                           TypeRVec,dealloc_TypeRVec
#endif
                                           
  USE mod_SymAbelian,               ONLY : Calc_symab1_EOR_symab2
  USE mod_psi_Op,                   ONLY : Set_symab_OF_psiBasisRep

  USE mod_psi_set_alloc,            ONLY : param_psi,ecri_psi
  USE mod_SetOp,                    ONLY : param_Op,write_param_Op
  USE mod_MPI
#if(run_MPI)
  USE mod_MPI_Aid
#endif
  IMPLICIT NONE

  TYPE (param_psi), intent(in)      :: Psi(:)
  TYPE (param_psi), intent(inout)   :: OpPsi(:)
  TYPE (param_Op),  intent(inout)   :: para_Op

  ! local variables
  TYPE (zmatrix), pointer :: mole
  TYPE (basis),   pointer :: BasisnD

  TYPE (TypeRVec),   allocatable    :: PsiR(:)
  
  Real (kind=Rkind), allocatable       :: PsiR_temp(:) 
  Real (kind=Rkind), allocatable       :: all_RvecB_temp(:)
  Real (kind=Rkind), allocatable       :: all_RvecB_temp2(:)
#if(run_MPI)
  TYPE (multi_array4),save,allocatable :: nDI_index_master(:)
#endif
  integer                              :: ib,i,iG,iiG,nb_thread
  integer                              :: itab,ith,iterm00,packet_size,OpPsi_symab
  integer, allocatable                 :: tab_l(:)
  logical                              :: not_init

#if(run_MPI)
  integer                              :: iG_MPI,ii  
  integer                              :: PsiR_V_iG_size
  integer(kind=MPI_INTEGER_KIND),save  :: Psi_size_MPI0
  integer                              :: PsiR_temp_count
  integer                              :: PsiR_temp_count2
  integer                              :: PsiR_temp_count_iG
  integer(kind=MPI_INTEGER_KIND)       :: PsiR_temp_length(0:MPI_np-1)
  integer(kind=MPI_INTEGER_KIND),save,allocatable :: total_Vlength_master(:)
  integer*4,save,allocatable           :: nDI_index(:)
  integer*4,save,allocatable           :: nDI_index_list(:)
  integer,save                         :: Max_nDI_ib0
  integer(kind=MPI_INTEGER_KIND),save  :: total_Vlength
  integer(kind=MPI_INTEGER_KIND),save,allocatable :: size_PsiR_V(:) 
#endif

  !----- for debuging ----------------------------------------------
  character (len=*), parameter :: name_sub='sub_TabOpPsi_FOR_SGtype4'
  logical, parameter :: debug = .FALSE.
  !logical, parameter :: debug = .TRUE.
  !-----------------------------------------------------------------
  IF (debug) THEN
    write(out_unitp,*) 'BEGINNING ',name_sub
    write(out_unitp,*) 'nb_bie,nb_baie',para_Op%nb_bie,para_Op%nb_baie
    write(out_unitp,*) 'nb_act1',para_Op%mole%nb_act1
    write(out_unitp,*) 'nb_var',para_Op%mole%nb_var
    !CALL flush_perso(out_unitp)
    !CALL write_param_Op(para_Op)
    write(out_unitp,*)
    write(out_unitp,*) 'PsiBasisRep'
    !DO itab=1,size(Psi)
      !CALL ecri_psi(Psi=Psi(itab))
    !END DO
    CALL flush_perso(out_unitp)
  END IF
  !-----------------------------------------------------------------------------
  mole    => para_Op%mole
  BasisnD => para_Op%BasisnD

  IF(MPI_id==0) THEN
    IF (Psi(1)%cplx) STOP 'cplx'
  ENDIF
  !IF (para_Op%nb_bie /= 1) STOP 'nb_bie /= 1 in sub_TabOpPsi_FOR_SGtype4'

  !-----------------------------------------------------------------------------
  IF (SG4_omp == 0) THEN
    nb_thread = 1
  ELSE
    nb_thread = SG4_maxth
  END IF
  !-----------------------------------------------------------------------------

  nb_mult_OpPsi = 0
  IF(MPI_id==0) THEN
    DO itab=1,size(Psi)
      OpPsi(itab)           = Psi(itab) ! for the allocation. It has to be changed!
      OpPsi(itab)%RvecB(:)  = ZERO
    END DO
  ENDIF

  IF (print_level > 0 .AND. BasisnD%para_SGType2%nb_SG > 10**4 ) THEN
    write(out_unitp,'(a)')              'OpPsi SG4 (%): [-10-20-30-40-50-60-70-80-90-100]'
    write(out_unitp,'(a)',ADVANCE='no') 'OpPsi SG4 (%): ['
    CALL flush_perso(out_unitp)
  END IF

  ! MPI version 3.3
#if(run_MPI)  
  IF(openmpi) THEN 

    CALL system_clock(time_point1,time_rate)
    IF(once_control) CALL time_perso('MPI loop in action begin')
    ! simple parallel case, equally devided for different threads
    nb_per_MPI=BasisnD%para_SGType2%nb_SG/MPI_np
    !If(mod(BasisnD%para_SGType2%nb_SG,MPI_np)/=0) nb_per_MPI=nb_per_MPI+1
    nb_rem_MPI=mod(BasisnD%para_SGType2%nb_SG,MPI_np)
    
    IF(once_control) THEN
      allocate(size_PsiR_V(0:MPI_np-1))
      !size of %V for each thread
      Do i_mpi=0,MPI_np-1
        size_PsiR_V(i_mpi)=0;
        !DO iG=i_mpi*nb_per_MPI+1,MIN((i_mpi+1)*nb_per_MPI,BasisnD%para_SGType2%nb_SG)
        DO iG=i_mpi*nb_per_MPI+1+MIN(i_mpi,nb_rem_MPI),                                &
           (i_mpi+1)*nb_per_MPI+ MIN(i_mpi,nb_rem_MPI)+merge(1,0,nb_rem_MPI>i_mpi)
          temp_int=BasisnD%para_SGType2%tab_nb_OF_SRep(iG)*BasisnD%para_SGType2%nb0
          size_PsiR_V(i_mpi)=size_PsiR_V(i_mpi)+temp_int
        ENDDO
      ENDDO
      write(*,*) 'size_PsiR_V:',size_PsiR_V(MPI_id),'from',MPI_id
    ENDIF
    ! case works better for propagation or cores > 10
    !-----------------------------------------------------------------------------------

    !IF((if_propa .AND. MPI_np>10) .OR. MPI_np>50) THEN 
    IF(size_PsiR_V(0)<1000000) THEN  !< according to the a few effeiciency test
      ! calculate total length of vectors for each threads------------------------------
      IF(once_control .AND. MPI_id==0) write(*,*) 'MPI TYPE 1 in action'
      IF(once_control .AND. MPI_id==0) THEN
        allocate(nDI_index_master(0:MPI_np-1))
        allocate(total_Vlength_master(0:MPI_np-1))
      ENDIF

      If(MPI_id==0) THEN
        Psi_size_MPI0=INT(size(Psi),MPI_INTEGER_KIND) ! for itab
        Max_nDI_ib0=size(psi(1)%RvecB)/BasisnD%para_SGType2%nb0
      ENDIF
      CALL MPI_BCAST(Psi_size_MPI0,size1_MPI,MPI_int,root_MPI,MPI_COMM_WORLD,MPI_err)
      CALL MPI_BCAST(Max_nDI_ib0,size1_MPI,MPI_int_fortran,root_MPI,                   &
                     MPI_COMM_WORLD,MPI_err)
           
      ! clean PsiR     
      IF(allocated(PsiR)) deallocate(PsiR)
      allocate(PsiR(Psi_size_MPI0))
      ! works on the other threads
      !---------------------------------------------------------------------------------
      ! all information for total_Vlength_MPI is keeped on master
      ! each thread keep its own    
      IF(MPI_id/=0) THEN
        !-generate index,  once only----------------------------------------------------
        IF(once_control) THEN
          num_nDI_index=size_PsiR_V(MPI_id)/10 ! initial size
          total_Vlength=0
          allcount=0
          CALL allocate_array(nDI_index,num_nDI_index)
          CALL allocate_array(nDI_index_list,size_PsiR_V(MPI_id))
          !DO iG=MPI_id*nb_per_MPI+1,                                                   &
          !      MIN((MPI_id+1)*nb_per_MPI,BasisnD%para_SGType2%nb_SG) 
          DO iG=MPI_id*nb_per_MPI+1+MIN(MPI_id,nb_rem_MPI),                            &
               (MPI_id+1)*nb_per_MPI+MIN(MPI_id,nb_rem_MPI)+merge(1,0,nb_rem_MPI>MPI_id)
          
            ! note size(psi(i)%RvecB) same for all i 
            CALL PackedBasis_TO_tabR_index(iG,BasisnD%para_SGType2,                    &
                                     total_Vlength,nDI_index,Max_nDI_ib0,nDI_index_list)
          ENDDO
          CALL MPI_Send(total_Vlength,size1_MPI,MPI_int,root_MPI,MPI_id,               &
                        MPI_COMM_WORLD,MPI_err)
          CALL MPI_Send(nDI_index(1:total_Vlength),total_Vlength,MPI_integer4,root_MPI,&    
                                  MPI_id,MPI_COMM_WORLD,MPI_err)
          write(*,*) 'allcount check',allcount,size_PsiR_V(MPI_id),total_Vlength,      &
                     ' from ',MPI_id
        ENDIF
        
        !-wait for master---------------------------------------------------------------
        CALL allocate_array(all_RvecB_temp,total_Vlength*Psi_size_MPI0)
        CALL allocate_array(all_RvecB_temp2,total_Vlength*Psi_size_MPI0)
        Call MPI_Recv(all_RvecB_temp,total_Vlength*Psi_size_MPI0,MPI_REAL8,root_MPI,   &
                      MPI_id,MPI_COMM_WORLD,MPI_stat,MPI_err)
         
        !-calculation on threads--------------------------------------------------------
        allcount=0
        allcount2=0   
        !DO iG=MPI_id*nb_per_MPI+1,                                                     &
        !      MIN((MPI_id+1)*nb_per_MPI,BasisnD%para_SGType2%nb_SG)    
        DO iG=MPI_id*nb_per_MPI+1+MIN(MPI_id,nb_rem_MPI),                              &
               (MPI_id+1)*nb_per_MPI+MIN(MPI_id,nb_rem_MPI)+merge(1,0,nb_rem_MPI>MPI_id)

          ! all_RvecB_temp --> PsiR
          CALL tabPackedBasis_TO_tabR_MPI(PsiR,all_RvecB_temp,iG,BasisnD%para_SGType2, &
                       nDI_index,total_Vlength,Psi_size_MPI0,Max_nDI_ib0,nDI_index_list)
                         
          !-main calculation------------------------------------------------------------
          CALL sub_TabOpPsi_OF_ONEDP_FOR_SGtype4(PsiR,iG,                              &
                          BasisnD%para_SGType2%nDind_SmolyakRep%Tab_nDval(:,iG),para_Op)                        
          !-pack PsiR in the slave threads----------------------------------------------
          CALL tabR_TO_tabPackedBasis_MPI(all_RvecB_temp2,PsiR,iG,                     &
                                          BasisnD%para_SGType2,BasisnD%WeightSG(iG),   &
                                          nDI_index,total_Vlength,Psi_size_MPI0,       &
                                          Max_nDI_ib0,nDI_index_list)
        ENDDO 
        
        !-send packed PsiR to master----------------------------------------------------
        !> check length of integer
        IF(total_Vlength*Psi_size_MPI0>2147483647 .AND. MPI_INTEGER_KIND==4) THEN
          STOP 'integer exceed 32-bit MPI, use 64-bit MPI instead'
        ENDIF
        CALL MPI_Send(all_RvecB_temp2,total_Vlength*Psi_size_MPI0,MPI_REAL8,root_MPI,  &
                      MPI_id,MPI_COMM_WORLD,MPI_err)
                     
      ENDIF ! for MPI_id/=0  
  
      ! works on the master threads
      !---------------------------------------------------------------------------------
      ! save index information for all threads on master & send vectors to other threads
      IF(MPI_id==0) THEN
        ! works for the other threads---------------------------------------------------
        Do i_mpi=1,MPI_np-1
          !-wait for other threads------------------------------------------------------
          CALL system_clock(time_temp1,time_rate)
          IF(once_control) THEN
            CALL MPI_Recv(total_Vlength,size1_MPI,MPI_int,i_mpi,i_mpi,                 &
                          MPI_COMM_WORLD,MPI_stat,MPI_err)
            total_Vlength_master(i_mpi)=total_Vlength
            allocate(nDI_index_master(i_mpi)%array(total_Vlength))
            CALL MPI_Recv(nDI_index_master(i_mpi)%array,total_Vlength,MPI_integer4,    &
                          i_mpi,i_mpi,MPI_COMM_WORLD,MPI_stat,MPI_err)
            write(*,*) 'length of comm list:',total_Vlength_master(i_mpi),'from',i_mpi
          ENDIF ! for once_control
          CALL system_clock(time_temp2,time_rate)
          time_comm=time_comm+time_temp2-time_temp1

          ! pack vectores to send
          CALL allocate_array(all_RvecB_temp,total_Vlength_master(i_mpi)*Psi_size_MPI0)
          DO itab=1,Psi_size_MPI0
            DO ii=1,total_Vlength_master(i_mpi)
              temp_int=(itab-1)*total_Vlength_master(i_mpi)+ii
              all_RvecB_temp(temp_int)=psi(itab)%RvecB(nDI_index_master(i_mpi)%array(ii))
            ENDDO
          ENDDO

          CALL system_clock(time_temp1,time_rate)
          CALL MPI_Send(all_RvecB_temp,total_Vlength_master(i_mpi)*Psi_size_MPI0,      &
                        MPI_REAL8,i_mpi,i_mpi,MPI_COMM_WORLD,MPI_err)
          CALL system_clock(time_temp2,time_rate)
          time_comm=time_comm+time_temp2-time_temp1

        ENDDO ! for i_mpi=1,MPI_np-1

        !-calculation on master---------------------------------------------------------
        !DO iG=MPI_id*nb_per_MPI+1,                                                     &
        !    MIN((MPI_id+1)*nb_per_MPI,BasisnD%para_SGType2%nb_SG)   
        DO iG=MPI_id*nb_per_MPI+1+MIN(MPI_id,nb_rem_MPI),                              &
              (MPI_id+1)*nb_per_MPI+MIN(MPI_id,nb_rem_MPI)+merge(1,0,nb_rem_MPI>MPI_id)

          DO itab=1,Psi_size_MPI0
            CALL tabPackedBasis_TO_tabR_AT_iG(PsiR(itab)%V,psi(itab)%RvecB,            &
                                              iG,BasisnD%para_SGType2)
          ENDDO 
          
          !-main calculation------------------------------------------------------------
          CALL sub_TabOpPsi_OF_ONEDP_FOR_SGtype4(PsiR,iG,                              &
                          BasisnD%para_SGType2%nDind_SmolyakRep%Tab_nDval(:,iG),para_Op) 
                
          DO itab=1,Psi_size_MPI0
            CALL tabR_AT_iG_TO_tabPackedBasis(OpPsi(itab)%RvecB,PsiR(itab)%V,          &
                                           iG,BasisnD%para_SGType2,BasisnD%WeightSG(iG))
          ENDDO 

        ENDDO ! for iG

        !-receive results from slave threads--------------------------------------------
        Do i_mpi=1,MPI_np-1
          CALL allocate_array(all_RvecB_temp,total_Vlength_master(i_mpi)*Psi_size_MPI0)
          CALL system_clock(time_temp1,time_rate)
          CALL MPI_Recv(all_RvecB_temp,total_Vlength_master(i_mpi)*Psi_size_MPI0,      &
                        MPI_REAL8,i_mpi,i_mpi,MPI_COMM_WORLD,MPI_stat,MPI_err)
          CALL system_clock(time_temp2,time_rate)
          time_comm=time_comm+time_temp2-time_temp1
          
          !-extract results from other threads------------------------------------------
          DO itab=1,Psi_size_MPI0
            Do ii=1,total_Vlength_master(i_mpi)             
              temp_int=nDI_index_master(i_mpi)%array(ii)
              OpPsi(itab)%RvecB(temp_int)=OpPsi(itab)%RvecB(temp_int)                  &
                                +all_RvecB_temp((itab-1)*total_Vlength_master(i_mpi)+ii)
            ENDDO 
          ENDDO
        ENDDO ! for i_mpi=1,MPI_np-1
      ENDIF ! for MPI_id==0
                    
      IF(allocated(all_RvecB_temp))  deallocate(all_RvecB_temp)
      IF(allocated(all_RvecB_temp2)) deallocate(all_RvecB_temp2)
      DO itab=1,Psi_size_MPI0
        CALL dealloc_TypeRVec(PsiR(itab))
      END DO
      !once_control=.FALSE.
      !---------------------------------------------------------------------------------  
    ELSE
      !---------------------------------------------------------------------------------  
      ! case for less cores in Davidson or arpark calculation      
      !--------------------------------------------------------------------------------- 
      IF(once_control .AND. MPI_id==0) write(*,*) 'MPI TYPE 2 in action'
      If(MPI_id==0) Psi_size_MPI0=size(Psi) ! for itab
      CALL MPI_BCAST(Psi_size_MPI0,size1_MPI,MPI_int,root_MPI,MPI_COMM_WORLD,MPI_err)
      IF(allocated(PsiR)) deallocate(PsiR)
      allocate(PsiR(Psi_size_MPI0))
      !---------------------------------------------------------------------------------
      IF(MPI_id==0) THEN
        !-prepare PsiR(itab)%V to be send to other threads------------------------------
        DO i_mpi=1,MPI_np-1
          If(allocated(PsiR_temp)) deallocate(PsiR_temp)
          allocate(PsiR_temp(Psi_size_MPI0*size_PsiR_V(i_mpi)))
          !CALL allocate_array(PsiR_temp,Psi_size_MPI0*size_PsiR_V(i_mpi))
          PsiR_temp_count=0
          !DO iG_MPI=i_mpi*nb_per_MPI+1,                                                &
          !          MIN((i_mpi+1)*nb_per_MPI,BasisnD%para_SGType2%nb_SG)
          DO iG_MPI=i_mpi*nb_per_MPI+1+MIN(i_mpi,nb_rem_MPI),                              &
             (i_mpi+1)*nb_per_MPI+MIN(i_mpi,nb_rem_MPI)+merge(1,0,nb_rem_MPI>i_mpi)

            DO itab=1,Psi_size_MPI0
              CALL tabPackedBasis_TO_tabR_AT_iG(PsiR(itab)%V,psi(itab)%RvecB,          &
                                                iG_MPI,BasisnD%para_SGType2)
              PsiR_temp_count2=PsiR_temp_count+size(PsiR(itab)%V)
              PsiR_temp(PsiR_temp_count+1:PsiR_temp_count2)=PsiR(itab)%V
              PsiR_temp_count=PsiR_temp_count2
            ENDDO
          ENDDO ! for iG_MPI
          PsiR_temp_length(i_mpi)=PsiR_temp_count
          
          ! double check
          IF(Abs(Psi_size_MPI0*size_PsiR_V(i_mpi)-PsiR_temp_length(i_mpi))>0) THEN
            write(*,*) 'error in MPI action part,check length'
            STOP
          ENDIF
                  
          CALL system_clock(time_temp1,time_rate)
          CALL MPI_Send(PsiR_temp,Psi_size_MPI0*size_PsiR_V(i_mpi),MPI_REAL8,i_mpi,    &
                        i_mpi,MPI_COMM_WORLD,MPI_err)
          CALL system_clock(time_temp2,time_rate)
          time_comm=time_comm+time_temp2-time_temp1
        ENDDO
        !-------------------------------------------------------------------------------

        !-calculations on MPI_id=0------------------------------------------------------
        !DO iG=MPI_id*nb_per_MPI+1,                                                     &
        !    MIN((MPI_id+1)*nb_per_MPI,BasisnD%para_SGType2%nb_SG)
        DO iG=MPI_id*nb_per_MPI+1+MIN(MPI_id,nb_rem_MPI),                              &
           (MPI_id+1)*nb_per_MPI+MIN(MPI_id,nb_rem_MPI)+merge(1,0,nb_rem_MPI>MPI_id)

          !-transfore to SRep-----------------------------------------------------------
          DO itab=1,Psi_size_MPI0
            CALL tabPackedBasis_TO_tabR_AT_iG(PsiR(itab)%V,psi(itab)%RvecB,            &
                                              iG,BasisnD%para_SGType2)
          ENDDO

          !-main calculation------------------------------------------------------------
          CALL sub_TabOpPsi_OF_ONEDP_FOR_SGtype4(PsiR,iG,                              &
                          BasisnD%para_SGType2%nDind_SmolyakRep%Tab_nDval(:,iG),para_Op)  
          
          
          !-back to compact form--------------------------------------------------------
          DO itab=1,Psi_size_MPI0
            CALL tabR_AT_iG_TO_tabPackedBasis(OpPsi(itab)%RvecB,PsiR(itab)%V,          &
                                           iG,BasisnD%para_SGType2,BasisnD%WeightSG(iG))
          ENDDO
        ENDDO ! main loop of iG for calcuation on master

        !-receive results from other threads--------------------------------------------
        DO i_mpi=1,MPI_np-1
          CALL system_clock(time_temp1,time_rate)
          If(allocated(PsiR_temp)) deallocate(PsiR_temp)
          allocate(PsiR_temp(Psi_size_MPI0*size_PsiR_V(i_mpi)))
          !CALL allocate_array(PsiR_temp,Psi_size_MPI0*size_PsiR_V(i_mpi))
          CALL MPI_Recv(PsiR_temp,Psi_size_MPI0*size_PsiR_V(i_mpi),MPI_REAL8,i_mpi,    &
                        i_mpi,MPI_COMM_WORLD,MPI_stat,MPI_err)
          CALL system_clock(time_temp2,time_rate)
          time_comm=time_comm+time_temp2-time_temp1

          PsiR_temp_count=0
          !DO iG_MPI=i_mpi*nb_per_MPI+1,                                                &
          !          MIN((i_mpi+1)*nb_per_MPI,BasisnD%para_SGType2%nb_SG)
          DO iG_MPI=i_mpi*nb_per_MPI+1+MIN(i_mpi,nb_rem_MPI),                          &
             (i_mpi+1)*nb_per_MPI+MIN(i_mpi,nb_rem_MPI)+merge(1,0,nb_rem_MPI>i_mpi)
            PsiR_V_iG_size=BasisnD%para_SGType2%tab_nb_OF_SRep(iG_MPI)                 &
                          *BasisnD%para_SGType2%nb0
            DO itab=1,Psi_size_MPI0
              PsiR_temp_count2=PsiR_temp_count+PsiR_V_iG_size
              IF(allocated(PsiR(itab)%V)) deallocate(PsiR(itab)%V)
              allocate(PsiR(itab)%V(PsiR_V_iG_size))
              PsiR(itab)%V=PsiR_temp(PsiR_temp_count+1:PsiR_temp_count2)
              PsiR_temp_count=PsiR_temp_count2
              CALL tabR_AT_iG_TO_tabPackedBasis(OpPsi(itab)%RvecB,PsiR(itab)%V,        &
                                   iG_MPI,BasisnD%para_SGType2,BasisnD%WeightSG(iG_MPI))
            ENDDO
          ENDDO
        ENDDO  ! for i_mpi=1,MPI_np-1    
      ENDIF ! for MPI_id==0
      
      !-calculation on other threads----------------------------------------------------
      IF(MPI_id/=0) THEN
        allocate(PsiR_temp(Psi_size_MPI0*size_PsiR_V(MPI_id)))
        ! waiting for master, get PsiR(itab)%V
        CALL MPI_Recv(PsiR_temp,Psi_size_MPI0*size_PsiR_V(MPI_id),MPI_REAL8,root_MPI,  &
                      MPI_id,MPI_COMM_WORLD,MPI_stat,MPI_err)
                                
        !-loop for main calculation-----------------------------------------------------
        PsiR_temp_count=0
        !DO iG=MPI_id*nb_per_MPI+1,                                                     &
        !    MIN((MPI_id+1)*nb_per_MPI,BasisnD%para_SGType2%nb_SG)
        DO iG=MPI_id*nb_per_MPI+1+MIN(MPI_id,nb_rem_MPI),                              &
              (MPI_id+1)*nb_per_MPI+MIN(MPI_id,nb_rem_MPI)+merge(1,0,nb_rem_MPI>MPI_id)

          PsiR_temp_count_iG=PsiR_temp_count
          PsiR_V_iG_size=BasisnD%para_SGType2%tab_nb_OF_SRep(iG)*BasisnD%para_SGType2%nb0
          
          !-extract SRep from PsiR_temp-------------------------------------------------
          DO itab=1,Psi_size_MPI0
            PsiR_temp_count2=PsiR_temp_count+PsiR_V_iG_size
            !IF(allocated(PsiR(itab)%V)) deallocate(PsiR(itab)%V)
            !allocate(PsiR(itab)%V(PsiR_V_iG_size))
            PsiR(itab)%V=PsiR_temp(PsiR_temp_count+1:PsiR_temp_count2)
            PsiR_temp_count=PsiR_temp_count2
          ENDDO

          !-main calculation------------------------------------------------------------
          CALL sub_TabOpPsi_OF_ONEDP_FOR_SGtype4(PsiR,iG,                              &
                          BasisnD%para_SGType2%nDind_SmolyakRep%Tab_nDval(:,iG),para_Op)  
          
          !-pack and PsiR(itab)%V-------------------------------------------------------
          Do itab=1,Psi_size_MPI0
            !PsiR_temp_count2=PsiR_temp_count_iG+PsiR_V_iG_size
            !PsiR_temp(PsiR_temp_count_iG+1:PsiR_temp_count2)=PsiR(itab)%V
            !PsiR_temp_count_iG=PsiR_temp_count2
            PsiR_temp(PsiR_temp_count_iG+1:PsiR_temp_count_iG+size(PsiR(itab)%V))=PsiR(itab)%V
            PsiR_temp_count_iG=PsiR_temp_count_iG+size(PsiR(itab)%V)
          ENDDO
        ENDDO ! for iG
        
        !-send back PsiR(itab)%V--------------------------------------------------------
        CALL MPI_Send(PsiR_temp,Psi_size_MPI0*size_PsiR_V(MPI_id),MPI_REAL8,           &
                      root_MPI,MPI_id,MPI_COMM_WORLD,MPI_err)
      ENDIF ! for MPI_id/=0
      !---------------------------------------------------------------------------------

      If(allocated(PsiR_temp)) deallocate(PsiR_temp)
      DO itab=1,Psi_size_MPI0
        CALL dealloc_TypeRVec(PsiR(itab))
      END DO
         
      !once_control=.FALSE.    
    ENDIF ! for size_PsiR_V(0)<2600000
    !-----------------------------------------------------------------------------------

    CALL system_clock(time_point2,time_rate)
    time_MPI_action=time_MPI_action+(time_point2-time_point1)
    IF(once_control .AND. MPI_id==0) write(*,*) 'time MPI comm check: ',time_comm,     &
                                                ' from ', MPI_id
    IF(once_control) CALL time_perso('MPI loop in action end') 
    once_control=.FALSE.
  ELSE
#endif
    ! non openmpi cases
    !---------------------------------------------------------------------------
    ! for direct_KEO case
    IF (SG4_omp == 0 .AND. para_Op%direct_KEO) THEN
      write(6,*) 'coucou : SG4_omp == 0 .AND. para_Op%direct_KEO'  ; flush(6)

      DO iG=1,BasisnD%para_SGType2%nb_SG

        !write(6,*) 'iG',iG ;    CALL flush_perso(out_unitp)
        !transfert part of the psi(:)%RvecB(:) to PsiR(itab)%V
        allocate(PsiR(size(Psi)))
        ! transfer form basis to grid-------------------------------------------
        DO itab=1,size(Psi)
          CALL tabPackedBasis_TO_tabR_AT_iG(PsiR(itab)%V,psi(itab)%RvecB,    &
                                            iG,BasisnD%para_SGType2)
          !write(6,*) 'iG,itab,PsiR',iG,itab,PsiR(itab)%V  ;    CALL flush_perso(out_unitp)
        END DO
        !write(6,*) 'iG',iG, ' unpack done' ;    CALL flush_perso(out_unitp)

        CALL sub_TabOpPsi_OF_ONEDP_FOR_SGtype4_ompGrid(PsiR,iG,para_Op)
        !write(6,*) 'iG',iG, ' TabOpPsi done' ;    CALL flush_perso(out_unitp)

        !transfert back, PsiR(itab)%V (HPsi) to the psi(:)%RvecB(:)
        DO itab=1,size(Psi)
          CALL tabR_AT_iG_TO_tabPackedBasis(OpPsi(itab)%RvecB,PsiR(itab)%V,  &
                         iG,BasisnD%para_SGType2,BasisnD%WeightSG(iG))
        END DO
        !write(6,*) 'iG',iG, ' pack done' ;    CALL flush_perso(out_unitp)

        !deallocate PsiR(:)
        DO itab=1,size(Psi)
          CALL dealloc_TypeRVec(PsiR(itab))
        END DO
        deallocate(PsiR)

        IF (print_level > 0  .AND. BasisnD%para_SGType2%nb_SG > 10**4 .AND.    &
            mod(iG,max(1,BasisnD%para_SGType2%nb_SG/10)) == 0 .AND. MPI_id==0) THEN
          write(out_unitp,'(a)',ADVANCE='no') '---'
          CALL flush_perso(out_unitp)
        END IF

        !write(6,*) 'iG done:',iG ; flush(6)
      END DO
    ELSE IF (allocated(BasisnD%para_SGType2%nDind_SmolyakRep%Tab_nDval)) THEN
      !write(6,*) 'coucou : allo Tab_nDval=t' ; flush(6)

      packet_size=max(1,BasisnD%para_SGType2%nb_SG/SG4_maxth/10)
      !$OMP   PARALLEL DEFAULT(NONE)                              &
      !$OMP   SHARED(Psi,OpPsi)                                   &
      !$OMP   SHARED(para_Op,BasisnD)                             &
      !$OMP   SHARED(print_level,out_unitp,SG4_maxth,packet_size) &
      !$OMP   PRIVATE(iG,itab,PsiR)                               &
      !$OMP   NUM_THREADS(SG4_maxth)
      allocate(PsiR(size(Psi)))
      !!$OMP   DO SCHEDULE(DYNAMIC,packet_size)
      !!$OMP   DO SCHEDULE(GUIDED)
      !$OMP   DO SCHEDULE(STATIC)
      DO iG=1,BasisnD%para_SGType2%nb_SG
        !write(6,*) 'iG',iG ; flush(6)
        !transfert part of the psi(:)%RvecB(:) to PsiR(itab)%V
        DO itab=1,size(Psi)
          CALL tabPackedBasis_TO_tabR_AT_iG(PsiR(itab)%V,psi(itab)%RvecB,  &
                                            iG,BasisnD%para_SGType2)
          !write(6,*) 'iG,itab,PsiR',iG,itab,PsiR(itab)%V
        END DO

        CALL sub_TabOpPsi_OF_ONEDP_FOR_SGtype4(PsiR,iG,                    &
             BasisnD%para_SGType2%nDind_SmolyakRep%Tab_nDval(:,iG),para_Op)

        !transfert back, PsiR(itab)%V (HPsi) to the psi(:)%RvecB(:)
        DO itab=1,size(Psi)
          CALL tabR_AT_iG_TO_tabPackedBasis(OpPsi(itab)%RvecB,PsiR(itab)%V,&
                             iG,BasisnD%para_SGType2,BasisnD%WeightSG(iG))
        END DO

        !deallocate PsiR(:)
        DO itab=1,size(Psi)
          CALL dealloc_TypeRVec(PsiR(itab))
        END DO

        IF (print_level > 0  .AND. BasisnD%para_SGType2%nb_SG > 10**4 .AND. &
            mod(iG,max(1,BasisnD%para_SGType2%nb_SG/10)) == 0 .AND. MPI_id==0) THEN
          write(out_unitp,'(a)',ADVANCE='no') '---'
          CALL flush_perso(out_unitp)
        END IF

        !write(6,*) 'iG done:',iG ; flush(6)
      END DO
      !$OMP   END DO
      deallocate(PsiR)
      !$OMP   END PARALLEL

    ELSE IF (BasisnD%para_SGType2%nb_tasks /= BasisnD%para_SGType2%nb_threads) THEN ! version 2
      !write(6,*) 'coucou : nb_tasks /= nb_threads'  ; flush(6)

      !$OMP parallel do                                             &
      !$OMP default(none)                                           &
      !$OMP shared(Psi,OpPsi,para_Op,BasisnD)                       &
      !$OMP private(i)                                              &
      !$OMP num_threads(SG4_maxth)
      DO i=1,BasisnD%para_SGType2%nb_tasks
        CALL sub_TabOpPsi_OF_SeveralDP_FOR_SGtype4(Psi,OpPsi,para_Op,          &
                      BasisnD%para_SGType2%nDval_init(:,i),                    &
               BasisnD%para_SGType2%iG_th(i),BasisnD%para_SGType2%fG_th(i))
      END DO
      !$OMP   END PARALLEL DO
    ELSE
      !write(6,*) 'coucou : with para_SGType2%nb_threads' ; flush(6)
      !to be sure to have the correct number of threads, we use
      !   BasisnD%para_SGType2%nb_threads 

      !$OMP parallel                                                &
      !$OMP default(none)                                           &
      !$OMP shared(Psi,OpPsi)                                       &
      !$OMP shared(para_Op,BasisnD,print_level,out_unitp)           &
      !$OMP private(itab,iG,iiG,tab_l,PsiR,ith)                     &
      !$OMP num_threads(BasisnD%para_SGType2%nb_threads)

      !--------------------------------------------------------------
      !-- For the initialization of tab_l(:) and the use of ADD_ONE_TO_nDindex in the parallel loop
      CALL alloc_NParray(tab_l,(/ BasisnD%para_SGType2%nDind_SmolyakRep%ndim /),'tabl_l',name_sub)
      ith = 0
      !$ ith = OMP_GET_THREAD_NUM()
      tab_l(:) = BasisnD%para_SGType2%nDval_init(:,ith+1)
      !--------------------------------------------------------------

      !write(6,*) 'ith,tab_l(:)',ith,':',tab_l

      ! we are not using the parallel do, to be able to use the correct initialized tab_l with nDval_init
      DO iG=BasisnD%para_SGType2%iG_th(ith+1),BasisnD%para_SGType2%fG_th(ith+1)
        !write(6,*) 'iG',iG ; flush(6)

        CALL ADD_ONE_TO_nDindex(BasisnD%para_SGType2%nDind_SmolyakRep,tab_l,iG=iG)

        !transfert part of the psi(:)%RvecB(:) to PsiR(itab)%V
        allocate(PsiR(size(Psi)))
        DO itab=1,size(Psi)
          CALL tabPackedBasis_TO_tabR_AT_iG(PsiR(itab)%V,psi(itab)%RvecB,    &
                                            iG,BasisnD%para_SGType2)
          !write(6,*) 'iG,itab,PsiR',iG,itab,PsiR(itab)%V
        END DO

        CALL sub_TabOpPsi_OF_ONEDP_FOR_SGtype4(PsiR,iG,tab_l,para_Op)

        !transfert back, PsiR(itab)%V (HPsi) to the psi(:)%RvecB(:)
        DO itab=1,size(Psi)
          CALL tabR_AT_iG_TO_tabPackedBasis(OpPsi(itab)%RvecB,PsiR(itab)%V,  &
                        iG,BasisnD%para_SGType2,BasisnD%WeightSG(iG))
        END DO

        !deallocate PsiR(:)
        DO itab=1,size(Psi)
          CALL dealloc_TypeRVec(PsiR(itab))
        END DO
        deallocate(PsiR)

        IF (print_level > 0  .AND. BasisnD%para_SGType2%nb_SG > 10**4 .AND. &
            mod(iG,max(1,BasisnD%para_SGType2%nb_SG/10)) == 0 .AND. MPI_id==0) THEN
          write(out_unitp,'(a)',ADVANCE='no') '---'
          CALL flush_perso(out_unitp)
        END IF

        !write(6,*) 'iG done:',iG ; flush(6)
      END DO
      CALL dealloc_NParray(tab_l,'tabl_l',name_sub)
      !$OMP   END PARALLEL
    END IF
#if(run_MPI)
  ENDIF ! for openmpi
#endif

  IF (print_level > 0 .AND. BasisnD%para_SGType2%nb_SG > 10**4) THEN
    write(out_unitp,'(a)',ADVANCE='yes') '-]'
  END IF
  CALL flush_perso(out_unitp)

  iterm00 = para_Op%derive_term_TO_iterm(0,0)
  IF (associated(para_Op%OpGrid)) THEN
    para_Op%OpGrid(iterm00)%para_FileGrid%Save_MemGrid_done =                  &
                      para_Op%OpGrid(iterm00)%para_FileGrid%Save_MemGrid
    para_Op%OpGrid(iterm00)%para_FileGrid%Save_FileGrid_done =                 &
                      para_Op%OpGrid(iterm00)%para_FileGrid%Save_FileGrid
    para_Op%OpGrid(iterm00)%para_FileGrid%Save_MemGrid_done=.True. 
  END IF

  IF(MPI_id==0) THEN
    DO i=1,size(OpPsi)
      !write(6,*) 'coucou symab Op psi',i,para_Op%symab,Psi(i)%symab
      OpPsi_symab = Calc_symab1_EOR_symab2(para_Op%symab,Psi(i)%symab)
      CALL Set_symab_OF_psiBasisRep(OpPsi(i),OpPsi_symab)
      !write(6,*) 'coucou symab Op.psi',i,OpPsi(i)%symab
 
      !write(out_unitp,*) 'para_Op,psi symab ',i,para_Op%symab,Psi(i)%symab
      !write(out_unitp,*) 'OpPsi_symab',i,OpPsi(i)%symab
    END DO
  ENDIF

  !-----------------------------------------------------------
  IF (debug) THEN
    write(out_unitp,*) 'OpPsiGridRep'
    !DO itab=1,size(Psi)
      !CALL ecri_psi(Psi=OpPsi(itab))
    !END DO
    write(out_unitp,*)
    write(out_unitp,*) 'END ',name_sub
  END IF
  !-----------------------------------------------------------

  END SUBROUTINE sub_TabOpPsi_FOR_SGtype4
!=======================================================================================

 SUBROUTINE sub_TabOpPsi_OF_SeveralDP_FOR_SGtype4(Psi,OpPsi,para_Op,    &
                                                  tab_l_init,initG,endG)
 USE mod_system
 USE mod_nDindex
 USE mod_Coord_KEO,                ONLY : zmatrix
 USE mod_basis_set_alloc,          ONLY : basis
 USE mod_basis_BtoG_GtoB_SGType4,  ONLY : tabPackedBasis_TO_tabR_AT_iG, &
                  tabR_AT_iG_TO_tabPackedBasis,TypeRVec,dealloc_TypeRVec
 USE mod_psi_set_alloc,            ONLY : param_psi,ecri_psi
 USE mod_SetOp,                    ONLY : param_Op,write_param_Op
 IMPLICIT NONE

 TYPE (param_psi), intent(in)      :: Psi(:)
 TYPE (param_psi), intent(inout)   :: OpPsi(:)

 TYPE (param_Op),  intent(inout)   :: para_Op
 integer,          intent(in)      :: initG,endG,tab_l_init(:)

 ! local variables
 TYPE (basis),      pointer        :: BasisnD
 TYPE (TypeRVec),   allocatable    :: PsiR(:)
 integer                           :: iG,itab
 integer,           allocatable    :: tab_l(:)

 !----- for debuging ----------------------------------------------
 character (len=*), parameter :: name_sub='sub_TabOpPsi_OF_SeveralDP_FOR_SGtype4'
 logical, parameter :: debug = .FALSE.
 !logical, parameter :: debug = .TRUE.
 !-----------------------------------------------------------------
 IF (debug) THEN
   write(out_unitp,*) 'BEGINNING ',name_sub
   CALL flush_perso(out_unitp)
 END IF
 !-----------------------------------------------------------------
  BasisnD => para_Op%BasisnD



   !--------------------------------------------------------------
   !-- For the initialization of tab_l(:) and the use of ADD_ONE_TO_nDindex in the parallel loop
   CALL alloc_NParray(tab_l,(/ BasisnD%para_SGType2%nDind_SmolyakRep%ndim /),&
                     'tab_l',name_sub)
   tab_l(:) = tab_l_init(:)
   !--------------------------------------------------------------

   DO iG=initG,endG

     CALL ADD_ONE_TO_nDindex(BasisnD%para_SGType2%nDind_SmolyakRep,tab_l,iG=iG)

     !write(6,*) 'iG',iG
     !transfert part of the psi(:)%RvecB(:) to PsiR(itab)%V
     allocate(PsiR(size(Psi)))
     DO itab=1,size(Psi)
       CALL tabPackedBasis_TO_tabR_AT_iG(PsiR(itab)%V,psi(itab)%RvecB,    &
                                         iG,BasisnD%para_SGType2)
       !write(6,*) 'iG,itab,PsiR',iG,itab,PsiR(itab)%V
     END DO

     CALL sub_TabOpPsi_OF_ONEDP_FOR_SGtype4(PsiR,iG,tab_l,para_Op)

     !transfert back, PsiR(itab)%V (HPsi) to the psi(:)%RvecB(:)
     DO itab=1,size(Psi)
       CALL tabR_AT_iG_TO_tabPackedBasis(OpPsi(itab)%RvecB,PsiR(itab)%V,  &
                     iG,BasisnD%para_SGType2,BasisnD%WeightSG(iG))
     END DO

     !deallocate PsiR(:)
     DO itab=1,size(Psi)
       CALL dealloc_TypeRVec(PsiR(itab))
     END DO
     deallocate(PsiR)

     IF (print_level > 0  .AND. BasisnD%para_SGType2%nb_SG > 10**4 .AND. &
         mod(iG,max(1,BasisnD%para_SGType2%nb_SG/10)) == 0 .AND. MPI_id==0) THEN
       write(out_unitp,'(a)',ADVANCE='no') '---'
       CALL flush_perso(out_unitp)
     END IF

   END DO

!-----------------------------------------------------------
 IF (debug) THEN
   write(out_unitp,*)
   write(out_unitp,*) 'END ',name_sub
 END IF
!-----------------------------------------------------------

  END SUBROUTINE sub_TabOpPsi_OF_SeveralDP_FOR_SGtype4


  SUBROUTINE sub_TabOpPsi_OF_ONEDP_FOR_SGtype4_old(PsiR,iG,tab_l,para_Op,PsiROnGrid)
  USE mod_system
  USE mod_nDindex

  USE mod_Coord_KEO,               ONLY : zmatrix, get_Qact, get_d0GG

  USE mod_basis_set_alloc,         ONLY : basis
  USE mod_basis,                   ONLY : Rec_Qact_SG4_with_Tab_iq
  USE mod_basis_BtoG_GtoB_SGType4, ONLY : TypeRVec,                     &
                     BDP_TO_GDP_OF_SmolyakRep,GDP_TO_BDP_OF_SmolyakRep, &
                  DerivOp_TO_RDP_OF_SmolaykRep,tabR2grid_TO_tabR1_AT_iG,&
                     getbis_tab_nq,getbis_tab_nb
  USE mod_SetOp,                      ONLY : param_Op,write_param_Op
  IMPLICIT NONE

  TYPE (TypeRVec),                    intent(inout)    :: PsiR(:)
  logical,          optional,         intent(in)       :: PsiROnGrid
  integer,                            intent(in)       :: iG,tab_l(:)

  TYPE (param_Op),                    intent(inout)    :: para_Op

  !local variables
  TYPE (zmatrix), pointer :: mole
  TYPE(basis),    pointer :: BasisnD

  integer :: iq,nb,nq,i,j,itab,D
  logical :: PsiROnBasis_loc

  integer                               :: derive_termQdyn(2)

  real (kind=Rkind),  allocatable       :: V(:,:,:)
  real(kind=Rkind),   allocatable       :: GridOp(:,:,:,:)
  real (kind=Rkind),  allocatable       :: GGiq(:,:,:)
  real (kind=Rkind),  allocatable       :: sqRhoOVERJac(:),Jac(:)
  real (kind=Rkind)                     :: Rho

  real (kind=Rkind),  allocatable       :: PsiRj(:,:),PsiRi(:),OpPsiR(:)
  real (kind=Rkind),  allocatable       :: PsiTemp1(:),PsiTemp2(:)

  integer,            allocatable       :: tab_nq(:)
  integer,            allocatable       :: tab_nb(:)
  integer :: iterm,iterm00
  integer :: err_sub


  !----- for debuging ----------------------------------------------
  integer :: err_mem,memory
  character (len=*), parameter :: name_sub='sub_TabOpPsi_OF_ONEDP_FOR_SGtype4_old'
  logical, parameter :: debug = .FALSE.
  !logical, parameter :: debug = .TRUE.
  !-----------------------------------------------------------------
  IF (debug) THEN
    write(out_unitp,*) 'BEGINNING ',name_sub
    write(out_unitp,*) 'nb_bie,nb_baie',para_Op%nb_bie,para_Op%nb_baie
    write(out_unitp,*) 'nb_act1',para_Op%mole%nb_act1
    write(out_unitp,*) 'nb_var',para_Op%mole%nb_var
    write(out_unitp,*) 'nb psi',size(PsiR)
    write(out_unitp,*) 'iG, tab_l(:)',iG,':',tab_l(:)
    write(out_unitp,*) 'nq',para_Op%BasisnD%para_SGType2%tab_nq_OF_SRep(iG)

    CALL flush_perso(out_unitp)
  END IF
  !-----------------------------------------------------------------
  !CALL Check_mem()

   !write(6,*) '================================' ; flush(6)
   !write(6,*) '============ START =============' ; flush(6)

   mole    => para_Op%mole
   BasisnD => para_Op%BasisnD

   IF (present(PsiROnGrid)) THEN
     PsiROnBasis_loc = .NOT. PsiROnGrid
   ELSE
     PsiROnBasis_loc = .TRUE.
   END IF
   D = size(tab_l)

   CALL alloc_NParray(tab_nb,(/ D /),'tab_nb',name_sub)
   CALL alloc_NParray(tab_nq,(/ D /),'tab_nq',name_sub)

   tab_nq(:) = getbis_tab_nq(tab_l,BasisnD%tab_basisPrimSG)
   tab_nb(:) = getbis_tab_nb(tab_l,BasisnD%tab_basisPrimSG)

   nb = size(PsiR(1)%V) ! because PsiR is in basis Rep
   nq = BasisnD%para_SGType2%tab_nq_OF_SRep(iG)

   SELECT CASE (para_Op%type_Op)
   CASE (0) ! 0 : Scalar

     CALL get_OpGrid_type0_OF_ONEDP_FOR_SG4(iG,tab_l,para_Op,V)

     DO itab=1,size(PsiR)

       IF (PsiROnBasis_loc) THEN
         ! partial B to G
         CALL BDP_TO_GDP_OF_SmolyakRep(PsiR(itab)%V,BasisnD%tab_basisPrimSG,&
                                       tab_l,tab_nq,tab_nb)
         PsiR(itab)%V(:) = PsiR(itab)%V(:) * V(:,1,1)

         ! partial B to G
         CALL GDP_TO_BDP_OF_SmolyakRep(PsiR(itab)%V,BasisnD%tab_basisPrimSG,&
                                       tab_l,tab_nq,tab_nb)
         ! now PsiR(itab)%V is on the Basis
       ELSE
         PsiR(itab)%V(:) = PsiR(itab)%V(:) * V(:,1,1)
       END IF

     END DO

     IF (allocated(V)) CALL dealloc_NParray(V,'V',name_sub)

   CASE (1) ! 1 : H: F2.d^2 + F1.d^1 + V
     IF (debug) write(out_unitp,*) 'nb_Term',para_Op%nb_Term

     CALL get_OpGrid_type1_OF_ONEDP_FOR_SG4_new2(iG,tab_l,para_Op,GridOp)

     CALL alloc_NParray(PsiTemp1,       (/ nq /),      'PsiTemp1',       name_sub)
     CALL alloc_NParray(PsiTemp2,       (/ nq /),      'PsiTemp2',       name_sub)

     DO itab=1,size(PsiR)

       IF (PsiROnBasis_loc) THEN
         ! partial B to G
         CALL BDP_TO_GDP_OF_SmolyakRep(PsiR(itab)%V,BasisnD%tab_basisPrimSG,&
                                       tab_l,tab_nq,tab_nb)

         PsiTemp1(:) = ZERO
         DO iterm=1,para_Op%nb_Term

           IF (para_Op%OpGrid(iterm)%grid_zero) CYCLE

           PsiTemp2(:) = PsiR(itab)%V(:)

           CALL DerivOp_TO_RDP_OF_SmolaykRep(PsiTemp2,BasisnD%tab_basisPrimSG, &
                               tab_l,tab_nq,para_Op%derive_termQdyn(:,iterm))

           PsiTemp1(:) = PsiTemp1(:) + PsiTemp2 * GridOp(:,1,1,iterm)

         END DO

         PsiR(itab)%V(:) = PsiTemp1(:)

         ! partial B to G
         CALL GDP_TO_BDP_OF_SmolyakRep(PsiR(itab)%V,BasisnD%tab_basisPrimSG,&
                                       tab_l,tab_nq,tab_nb)
         ! now PsiR(itab)%V is on the Basis
       ELSE

         PsiTemp1(:) = ZERO
         DO iterm=1,para_Op%nb_Term

           IF (para_Op%OpGrid(iterm)%grid_zero) CYCLE

           PsiTemp2(:) = PsiR(itab)%V(:)

           CALL DerivOp_TO_RDP_OF_SmolaykRep(PsiTemp2,BasisnD%tab_basisPrimSG, &
                               tab_l,tab_nq,para_Op%derive_termQdyn(:,iterm))

           PsiTemp1(:) = PsiTemp1(:) + PsiTemp2 * GridOp(:,1,1,iterm)

         END DO

         PsiR(itab)%V(:) = PsiTemp1(:)

       END IF

     END DO

     IF (allocated(GridOp))   CALL dealloc_NParray(GridOp,  'GridOp',  name_sub)
     IF (allocated(PsiTemp1)) CALL dealloc_NParray(PsiTemp1,'PsiTemp1',name_sub)
     IF (allocated(PsiTemp2)) CALL dealloc_NParray(PsiTemp2,'PsiTemp2',name_sub)

   CASE (10) !10: H: d^1 G d^1 +V

     CALL alloc_NParray(PsiRj,(/ nq,mole%nb_act1 /),'PsiRj',       name_sub)
     CALL alloc_NParray(PsiRi,       (/ nq /),      'PsiRi',       name_sub)


     CALL get_OpGrid_type10_OF_ONEDP_FOR_SG4(iG,tab_l,para_Op,V,GGiq,sqRhoOVERJac,Jac)


     DO itab=1,size(PsiR)

       CALL alloc_NParray(OpPsiR,(/nq/),'OpPsiR',name_sub)

       IF (PsiROnBasis_loc) THEN
         ! partial B to G
         CALL BDP_TO_GDP_OF_SmolyakRep(PsiR(itab)%V,BasisnD%tab_basisPrimSG,&
                                       tab_l,tab_nq,tab_nb)
       END IF

       ! now PsiR is on the grid
       !write(6,*) ' R Grid of PsiR(itab) :',PsiR(itab)%V
       !write(6,*) ' R Grid of PsiR(itab) : done',itab,OMP_GET_THREAD_NUM() ; flush(6)

       ! multiplication by sqRhoOVERJac
       PsiR(itab)%V(:) = PsiR(itab)%V(:) * sqRhoOVERJac(:)

       !write(6,*) ' R*sq Grid of PsiR(itab) :',PsiR
       !write(6,*) ' R*sq ... Grid of PsiR(itab) : done',itab,OMP_GET_THREAD_NUM() ; flush(6)


       ! derivative with respect to Qj
       DO j=1,mole%nb_act1
         derive_termQdyn(:) = (/ mole%liste_QactTOQsym(j),0 /)

         PsiRj(:,j) = PsiR(itab)%V(:)
         CALL DerivOp_TO_RDP_OF_SmolaykRep(PsiRj(:,j),BasisnD%tab_basisPrimSG, &
                                           tab_l,tab_nq,derive_termQdyn)

         !write(6,*) 'dQj Grid of PsiR(itab)',j,PsiRj(:,j) ; flush(6)
       END DO
       !write(6,*) ' dQj R*sq ... Grid of PsiR(itab) : done',itab,OMP_GET_THREAD_NUM() ; flush(6)

       OpPsiR(:) = ZERO
       DO i=1,mole%nb_act1

         PsiRi(:) = ZERO
         DO j=1,mole%nb_act1
           PsiRi(:) = PsiRi(:) + GGiq(:,j,i) * PsiRj(:,j)
         END DO
         PsiRi(:) = PsiRi(:) * Jac(:)
         !write(6,*) ' Jac Gij* ... Grid of SRep : done',iG,itab,i,OMP_GET_THREAD_NUM() ; flush(6)

         derive_termQdyn(:) = (/ mole%liste_QactTOQsym(i),0 /)

         CALL DerivOp_TO_RDP_OF_SmolaykRep(PsiRi(:),BasisnD%tab_basisPrimSG,&
                                           tab_l,tab_nq,derive_termQdyn)

         OpPsiR(:) = OpPsiR(:) + PsiRi(:)

       END DO
       !write(6,*) ' dQi Jac Gij* ... Grid of PsiR(itab) : done',itab,OMP_GET_THREAD_NUM() ; flush(6)

       OpPsiR(:) = (  -HALF*OpPsiR(:)/Jac(:) + PsiR(itab)%V(:)*V(:,1,1) ) / sqRhoOVERJac(:)
       !write(6,*) ' OpPsiR Grid of PsiR(itab)',OpPsiR
       !write(6,*) ' OpPsiR Grid of PsiR(itab) : done',itab,OMP_GET_THREAD_NUM() ; flush(6)

       !tranfert OpPsiR (on the grid) to PsiR(itab)
       PsiR(itab)%V(:) = OpPsiR(:)

       CALL dealloc_NParray(OpPsiR,'OpPsiR', name_sub)

       IF (PsiROnBasis_loc) THEN
         ! partial B to G
         CALL GDP_TO_BDP_OF_SmolyakRep(PsiR(itab)%V,BasisnD%tab_basisPrimSG,&
                                     tab_l,tab_nq,tab_nb)
         ! now PsiR(itab)%V is on the Basis
       END IF


     END DO

     IF (allocated(PsiRi))        CALL dealloc_NParray(PsiRi,       'PsiRi',       name_sub)
     IF (allocated(PsiRj))        CALL dealloc_NParray(PsiRj,       'PsiRj',       name_sub)
     IF (allocated(GGiq))         CALL dealloc_NParray(GGiq,        'GGiq',        name_sub)
     IF (allocated(sqRhoOVERJac)) CALL dealloc_NParray(sqRhoOVERJac,'sqRhoOVERJac',name_sub)
     IF (allocated(Jac))          CALL dealloc_NParray(Jac,         'Jac',         name_sub)
     IF (allocated(V))            CALL dealloc_NParray(V,           'V',           name_sub)


   CASE Default
     STOP 'no default'
   END SELECT

   IF (allocated(tab_nb)) CALL dealloc_NParray(tab_nb,'tab_nb',name_sub)
   IF (allocated(tab_nq)) CALL dealloc_NParray(tab_nq,'tab_nq',name_sub)
   !write(6,*) '============ END ===============' ; flush(6)
   !write(6,*) '================================' ; flush(6)
  !-----------------------------------------------------------
  IF (debug) THEN
    write(out_unitp,*) 'END ',name_sub
    CALL flush_perso(out_unitp)
  END IF
  !-----------------------------------------------------------
  !CALL UnCheck_mem() ; stop
  END SUBROUTINE sub_TabOpPsi_OF_ONEDP_FOR_SGtype4_old

!=======================================================================================
  SUBROUTINE sub_TabOpPsi_OF_ONEDP_FOR_SGtype4(PsiR,iG,tab_l,para_Op,PsiROnGrid)
  USE mod_system
  USE mod_nDindex

  USE mod_Coord_KEO,               ONLY : zmatrix, get_Qact, get_d0GG

  USE mod_basis_set_alloc,         ONLY : basis
  USE mod_basis,                   ONLY : Rec_Qact_SG4_with_Tab_iq
  USE mod_basis_BtoG_GtoB_SGType4, ONLY : TypeRVec,                     &
                     BDP_TO_GDP_OF_SmolyakRep,GDP_TO_BDP_OF_SmolyakRep, &
                  DerivOp_TO_RDP_OF_SmolaykRep,tabR2grid_TO_tabR1_AT_iG,&
                     getbis_tab_nq,getbis_tab_nb
  USE mod_SetOp,                      ONLY : param_Op,write_param_Op
  IMPLICIT NONE

  TYPE (TypeRVec),                    intent(inout)    :: PsiR(:)
  logical,          optional,         intent(in)       :: PsiROnGrid
  integer,                            intent(in)       :: iG,tab_l(:)

  TYPE (param_Op),                    intent(inout)    :: para_Op

  !local variables
  TYPE (zmatrix), pointer :: mole
  TYPE(basis),    pointer :: BasisnD

  integer :: iq,nb,nq,i,j,itab,D
  integer :: ib0,jb0,nb0,iqi,iqf,jqi,jqf,ibi,ibf

  logical :: PsiROnBasis_loc

  integer                               :: derive_termQdyn(2)

  real (kind=Rkind),  allocatable       :: V(:,:,:)
  real (kind=Rkind),  allocatable       :: GridOp(:,:,:,:)
  real (kind=Rkind),  allocatable       :: GGiq(:,:,:)
  real (kind=Rkind),  allocatable       :: sqRhoOVERJac(:),Jac(:)
  real (kind=Rkind)                     :: Rho

  real (kind=Rkind),  allocatable       :: PsiRj(:,:),PsiRi(:),OpPsiR(:),VPsi(:,:)
  real (kind=Rkind),  allocatable       :: OpPsi(:,:) ! size(nq,nb0)
  real (kind=Rkind),  allocatable       :: Psi_ch(:,:) ! size(nq,nb0)

  integer,            allocatable       :: tab_nq(:)
  integer,            allocatable       :: tab_nb(:)
  integer :: iterm,iterm00
  integer :: err_sub


  !----- for debuging ----------------------------------------------
  integer :: err_mem,memory
  character (len=*), parameter :: name_sub='sub_TabOpPsi_OF_ONEDP_FOR_SGtype4'
  logical, parameter :: debug = .FALSE.
  !logical, parameter :: debug = .TRUE.
  !-----------------------------------------------------------------
  IF (debug) THEN
    write(out_unitp,*) 'BEGINNING ',name_sub
    write(out_unitp,*) 'nb_bie,nb_baie',para_Op%nb_bie,para_Op%nb_baie
    write(out_unitp,*) 'nb_act1',para_Op%mole%nb_act1
    write(out_unitp,*) 'nb_var',para_Op%mole%nb_var
    write(out_unitp,*) 'nb psi',size(PsiR)
    write(out_unitp,*) 'iG, tab_l(:)',iG,':',tab_l(:)
    write(out_unitp,*) 'nb0',para_Op%BasisnD%para_SGType2%nb0
    write(out_unitp,*) 'nq',para_Op%BasisnD%para_SGType2%tab_nq_OF_SRep(iG)
    write(out_unitp,*) 'nb',para_Op%BasisnD%para_SGType2%tab_nb_OF_SRep(iG)
    IF (present(PsiROnGrid)) write(out_unitp,*) 'PsiROnGrid',PsiROnGrid
    CALL flush_perso(out_unitp)
  END IF
  !-----------------------------------------------------------------
  !CALL Check_mem()

   !write(6,*) '================================' ; flush(6)
   !write(6,*) '============ START =============' ; flush(6)

   mole    => para_Op%mole
   BasisnD => para_Op%BasisnD

   IF (present(PsiROnGrid)) THEN
     PsiROnBasis_loc = .NOT. PsiROnGrid
   ELSE
     PsiROnBasis_loc = .TRUE.
   END IF
   D = size(tab_l)

   CALL alloc_NParray(tab_nb,(/ D /),'tab_nb',name_sub)
   CALL alloc_NParray(tab_nq,(/ D /),'tab_nq',name_sub)

   tab_nq(:) = getbis_tab_nq(tab_l,BasisnD%tab_basisPrimSG)
   tab_nb(:) = getbis_tab_nb(tab_l,BasisnD%tab_basisPrimSG)

   nb  = BasisnD%para_SGType2%tab_nb_OF_SRep(iG)
   nq  = BasisnD%para_SGType2%tab_nq_OF_SRep(iG)
   nb0 = BasisnD%para_SGType2%nb0

   SELECT CASE (para_Op%type_Op)
   CASE (0) ! 0 : Scalar

     CALL get_OpGrid_type0_OF_ONEDP_FOR_SG4(iG,tab_l,para_Op,V)

     CALL alloc_NParray(OpPsi,(/nq,nb0/),'OpPsi',name_sub)

     DO itab=1,size(PsiR)

       OpPsi(:,:) = ZERO

       IF (PsiROnBasis_loc) THEN
         ! partial B to G
         CALL BDP_TO_GDP_OF_SmolyakRep(PsiR(itab)%V,BasisnD%tab_basisPrimSG,&
                                       tab_l,tab_nq,tab_nb,nb0)
       END IF

       ! VPsi calculation, it has to be done before because V is not diagonal
       DO ib0=1,nb0
         jqi = 1
         jqf = nq
         DO jb0=1,nb0
           OpPsi(:,ib0) = OpPsi(:,ib0) + V(:,ib0,jb0) * PsiR(itab)%V(jqi:jqf)
           jqi = jqf+1
           jqf = jqf+nq
         END DO
       END DO


       PsiR(itab)%V(:) = reshape(OpPsi,shape=(/nq*nb0/))

       IF (PsiROnBasis_loc) THEN
         ! partial B to G
         CALL GDP_TO_BDP_OF_SmolyakRep(PsiR(itab)%V,BasisnD%tab_basisPrimSG,&
                                       tab_l,tab_nq,tab_nb,nb0)
         ! now PsiR(itab)%V is on the Basis
       END IF

     END DO

     IF (allocated(V))     CALL dealloc_NParray(V,'V',name_sub)
     IF (allocated(OpPsi)) CALL dealloc_NParray(OpPsi,'OpPsi',name_sub)

   CASE (1) ! 1 : H: F2.d^2 + F1.d^1 + V
     IF (debug) write(out_unitp,*) 'nb_Term',para_Op%nb_Term

     CALL get_OpGrid_type1_OF_ONEDP_FOR_SG4_new2(iG,tab_l,para_Op,GridOp)

     CALL alloc_NParray(OpPsi,(/nq,nb0/),'OpPsi',name_sub)
     CALL alloc_NParray(Psi_ch,(/nq,nb0/),'Psi_ch',name_sub)


     DO itab=1,size(PsiR)

       IF (PsiROnBasis_loc) THEN
         ! partial B to G
           CALL BDP_TO_GDP_OF_SmolyakRep(PsiR(itab)%V,                  &
                                         BasisnD%tab_basisPrimSG,       &
                                         tab_l,tab_nq,tab_nb,nb0)
       END IF

       OpPsi(:,:) = ZERO

       DO iterm=1,para_Op%nb_Term
         IF (para_Op%OpGrid(iterm)%grid_zero) CYCLE

         Psi_ch(:,:) = reshape(PsiR(itab)%V,shape=(/nq,nb0/))
         DO ib0=1,nb0
           CALL DerivOp_TO_RDP_OF_SmolaykRep(Psi_ch(:,ib0),BasisnD%tab_basisPrimSG, &
                               tab_l,tab_nq,para_Op%derive_termQdyn(:,iterm))
         END DO


         ! GridOp(:,1,1,iterm)Psi_ch calculation
         DO ib0=1,nb0
         DO jb0=1,nb0
           OpPsi(:,ib0) = OpPsi(:,ib0) + GridOp(:,ib0,jb0,iterm) * Psi_ch(:,jb0)
         END DO
         END DO

       END DO


       PsiR(itab)%V(:) = reshape(OpPsi,shape=(/nq*nb0/))



       IF (PsiROnBasis_loc) THEN
         ! partial B to G
           CALL GDP_TO_BDP_OF_SmolyakRep(PsiR(itab)%V,                  &
                                         BasisnD%tab_basisPrimSG,       &
                                         tab_l,tab_nq,tab_nb,nb0)
         ! now PsiR(itab)%V is on the basis
       END IF

     END DO

     IF (allocated(GridOp))   CALL dealloc_NParray(GridOp,  'GridOp',  name_sub)
     IF (allocated(OpPsi))    CALL dealloc_NParray(OpPsi,   'OpPsi',name_sub)
     IF (allocated(Psi_ch))   CALL dealloc_NParray(Psi_ch,  'Psi_ch',name_sub)

   CASE (10) !10: H: d^1 G d^1 +V
     CALL alloc_NParray(PsiRj, (/ nq,mole%nb_act1 /),'PsiRj',       name_sub)
     CALL alloc_NParray(PsiRi,       (/ nq /),       'PsiRi',       name_sub)
     CALL alloc_NParray(VPsi,  (/nq,nb0/),           'VPsi',        name_sub)
     CALL alloc_NParray(OpPsiR,(/nq/),               'OpPsiR',      name_sub)


     CALL get_OpGrid_type10_OF_ONEDP_FOR_SG4(iG,tab_l,para_Op,V,GGiq,sqRhoOVERJac,Jac)


     DO itab=1,size(PsiR)

       IF (PsiROnBasis_loc) THEN
         ! partial B to G
         CALL BDP_TO_GDP_OF_SmolyakRep(PsiR(itab)%V,BasisnD%tab_basisPrimSG,&
                                       tab_l,tab_nq,tab_nb,nb0)
       END IF

       ! VPsi calculation, it has to be done before because V is not diagonal
       VPsi(:,:) = ZERO
       DO ib0=1,nb0
         jqi = 1
         jqf = nq
         DO jb0=1,nb0
           VPsi(:,ib0) = VPsi(:,ib0) + V(:,ib0,jb0) * PsiR(itab)%V(jqi:jqf)
           jqi = jqf+1
           jqf = jqf+nq
         END DO
       END DO

       iqi = 1
       iqf = nq
       DO ib0=1,nb0

         ! multiplication by sqRhoOVERJac
         PsiR(itab)%V(iqi:iqf) = PsiR(itab)%V(iqi:iqf) * sqRhoOVERJac(:)

         !write(6,*) ' R*sq Grid of PsiR :',PsiR%V
         !write(6,*) ' R*sq ... Grid of PsiR : done',OMP_GET_THREAD_NUM() ; flush(6)


         ! derivative with respect to Qj
         DO j=1,mole%nb_act1
           derive_termQdyn(:) = (/ mole%liste_QactTOQsym(j),0 /)

           PsiRj(:,j) = PsiR(itab)%V(iqi:iqf)
           CALL DerivOp_TO_RDP_OF_SmolaykRep(PsiRj(:,j),BasisnD%tab_basisPrimSG, &
                                             tab_l,tab_nq,derive_termQdyn)
           !write(6,*) 'dQj Grid of PsiR',j,PsiRj(:,j) ; flush(6)
         END DO
         !write(6,*) ' dQj R*sq ... Grid of PsiR : done',OMP_GET_THREAD_NUM() ; flush(6)

         OpPsiR(:) = ZERO
         DO i=1,mole%nb_act1

           PsiRi(:) = ZERO
           DO j=1,mole%nb_act1
             PsiRi(:) = PsiRi(:) + GGiq(:,j,i) * PsiRj(:,j)
           END DO
           PsiRi(:) = PsiRi(:) * Jac(:)
           !write(6,*) ' Jac Gij* ... Grid of SRep : done',iG,i,OMP_GET_THREAD_NUM() ; flush(6)

           derive_termQdyn(:) = (/ mole%liste_QactTOQsym(i),0 /)

           CALL DerivOp_TO_RDP_OF_SmolaykRep(PsiRi(:),BasisnD%tab_basisPrimSG,&
                                               tab_l,tab_nq,derive_termQdyn)

           !write(6,*) 'shape OpPsiR,PsiRi ',shape(OpPsiR),shape(PsiRi)
           !write(6,*) 'DerivOp_TO_RDP_OF_SmolaykRep : done',OMP_GET_THREAD_NUM() ; flush(6)

           OpPsiR(:) = OpPsiR(:) + PsiRi(:)
         END DO

         !write(6,*) ' dQi Jac Gij* ... Grid of PsiR : done',OMP_GET_THREAD_NUM() ; flush(6)

         OpPsiR(:) =   -HALF*OpPsiR(:) / ( Jac(:)*sqRhoOVERJac(:) ) + VPsi(:,ib0)
         !write(6,*) ' OpPsiR Grid of PsiR',OpPsiR
         !write(6,*) ' OpPsiR Grid of PsiR : done',OMP_GET_THREAD_NUM() ; flush(6)

         !tranfert OpPsiR (on the grid) to PsiR
         PsiR(itab)%V(iqi:iqf) = OpPsiR(:)

         iqi = iqf+1
         iqf = iqf+nq
       END DO

       IF (PsiROnBasis_loc) THEN
         ! partial B to G
         CALL GDP_TO_BDP_OF_SmolyakRep(PsiR(itab)%V,BasisnD%tab_basisPrimSG,&
                                     tab_l,tab_nq,tab_nb,nb0)
         ! now PsiR(itab)%V is on the Basis
       END IF


     END DO

     IF (allocated(PsiRi))        CALL dealloc_NParray(PsiRi,       'PsiRi',       name_sub)
     IF (allocated(PsiRj))        CALL dealloc_NParray(PsiRj,       'PsiRj',       name_sub)
     IF (allocated(GGiq))         CALL dealloc_NParray(GGiq,        'GGiq',        name_sub)
     IF (allocated(sqRhoOVERJac)) CALL dealloc_NParray(sqRhoOVERJac,'sqRhoOVERJac',name_sub)
     IF (allocated(Jac))          CALL dealloc_NParray(Jac,         'Jac',         name_sub)
     IF (allocated(V))            CALL dealloc_NParray(V,           'V',           name_sub)
     IF (allocated(VPsi))         CALL dealloc_NParray(VPsi        ,'VPsi',        name_sub)


   CASE Default
     STOP 'no default'
   END SELECT

   IF (allocated(tab_nb)) CALL dealloc_NParray(tab_nb,'tab_nb',name_sub)
   IF (allocated(tab_nq)) CALL dealloc_NParray(tab_nq,'tab_nq',name_sub)
   !write(6,*) '============ END ===============' ; flush(6)
   !write(6,*) '================================' ; flush(6)
  !-----------------------------------------------------------
  IF (debug) THEN
    write(out_unitp,*) 'END ',name_sub
    CALL flush_perso(out_unitp)
  END IF
  !-----------------------------------------------------------
  !CALL UnCheck_mem() ; stop
  END SUBROUTINE sub_TabOpPsi_OF_ONEDP_FOR_SGtype4
!=======================================================================================

  SUBROUTINE sub_TabOpPsi_OF_ONEGDP_WithOp_FOR_SGtype4(PsiR,iG,para_Op, &
                                                   V,GG,sqRhoOVERJac,Jac)
  USE mod_system

  USE mod_Coord_KEO,               ONLY : zmatrix, get_Qact

  USE mod_basis_set_alloc,         ONLY : basis
  USE mod_basis_BtoG_GtoB_SGType4, ONLY : TypeRVec,                     &
                     BDP_TO_GDP_OF_SmolyakRep,GDP_TO_BDP_OF_SmolyakRep, &
                   DerivOp_TO_RDP_OF_SmolaykRep,tabR2grid_TO_tabR1_AT_iG,&
                     getbis_tab_nq,getbis_tab_nb
  USE mod_SetOp,                      ONLY : param_Op,write_param_Op
  IMPLICIT NONE

  TYPE (TypeRVec),                    intent(inout)    :: PsiR(:)
  integer,                            intent(in)       :: iG

  TYPE (param_Op),                    intent(inout)    :: para_Op
  real (kind=Rkind),                  intent(in)       :: V(:)
  real (kind=Rkind),                  intent(in)       :: GG(:,:,:)
  real (kind=Rkind),                  intent(in)       :: sqRhoOVERJac(:),Jac(:)

  !local variables
  TYPE (zmatrix), pointer :: mole
  TYPE(basis),    pointer :: BasisnD

  integer :: iq,nb,nq,i,j,itab,D
  integer :: ib0,jb0,nb0,iqi,iqf,jqi,jqf

  integer                               :: derive_termQdyn(2)


  real (kind=Rkind)                     :: Rho

  real (kind=Rkind),  allocatable       :: PsiRj(:,:),PsiRi(:),OpPsiR(:)
  real (kind=Rkind),  allocatable       :: VPsi(:,:) ! size(nq,nb0)

  integer,            allocatable       :: tab_nq(:)
  integer,            allocatable       :: tab_nb(:)
  integer,            allocatable       :: tab_l(:)
  integer :: err_sub


  !----- for debuging ----------------------------------------------
  integer :: err_mem,memory
  character (len=*), parameter :: name_sub='sub_TabOpPsi_OF_ONEGDP_WithOp_FOR_SGtype4'
  logical, parameter :: debug = .FALSE.
  !logical, parameter :: debug = .TRUE.
  !-----------------------------------------------------------------
  IF (debug) THEN
    write(out_unitp,*) 'BEGINNING ',name_sub
    write(out_unitp,*) 'nb_bie,nb_baie',para_Op%nb_bie,para_Op%nb_baie
    write(out_unitp,*) 'nb_act1',para_Op%mole%nb_act1
    write(out_unitp,*) 'nb_var',para_Op%mole%nb_var
    CALL flush_perso(out_unitp)
  END IF
  !-----------------------------------------------------------------
  !CALL Check_mem()

   !write(6,*) '================================' ; flush(6)
   !write(6,*) '============ START =============' ; flush(6)

   mole    => para_Op%mole
   BasisnD => para_Op%BasisnD

   D = size(BasisnD%para_SGType2%nDind_SmolyakRep%Tab_nDval,dim=1)

   CALL alloc_NParray(tab_l ,(/ D /),'tab_l', name_sub)
   CALL alloc_NParray(tab_nb,(/ D /),'tab_nb',name_sub)
   CALL alloc_NParray(tab_nq,(/ D /),'tab_nq',name_sub)

   tab_l(:)  = BasisnD%para_SGType2%nDind_SmolyakRep%Tab_nDval(:,iG)
   tab_nq(:) = getbis_tab_nq(tab_l,BasisnD%tab_basisPrimSG)
   tab_nb(:) = getbis_tab_nb(tab_l,BasisnD%tab_basisPrimSG)


   nb = BasisnD%para_SGType2%tab_nb_OF_SRep(iG)
   nq = BasisnD%para_SGType2%tab_nq_OF_SRep(iG)
   nb0 = BasisnD%para_SGType2%nb0

   CALL alloc_NParray(PsiRj,(/ nq,mole%nb_act1 /),'PsiRj',       name_sub)
   CALL alloc_NParray(PsiRi,       (/ nq /),      'PsiRi',       name_sub)

   DO itab=1,size(PsiR)

     CALL alloc_NParray(OpPsiR,(/nq/),'OpPsiR',name_sub)

     ! partial B to G
     !!!!! no because PsiR(itab)%V(:) is already on the grid


     ! multiplication by sqRhoOVERJac
     PsiR(itab)%V(:) = PsiR(itab)%V(:) * sqRhoOVERJac(:)

     !write(6,*) ' R*sq Grid of PsiR(itab) :',PsiR
     !write(6,*) ' R*sq ... Grid of PsiR(itab) : done',itab,OMP_GET_THREAD_NUM() ; flush(6)


     ! derivative with respect to Qj
     DO j=1,mole%nb_act1
       derive_termQdyn(:) = (/ mole%liste_QactTOQsym(j),0 /)

       PsiRj(:,j) = PsiR(itab)%V(:)
       CALL DerivOp_TO_RDP_OF_SmolaykRep(PsiRj(:,j),BasisnD%tab_basisPrimSG, &
                                         tab_l,tab_nq,derive_termQdyn)

       !write(6,*) 'dQj Grid of PsiR(itab)',j,PsiRj(:,j) ; flush(6)
     END DO
     !write(6,*) ' dQj R*sq ... Grid of PsiR(itab) : done',itab,OMP_GET_THREAD_NUM() ; flush(6)

     OpPsiR(:) = ZERO
     DO i=1,mole%nb_act1

       PsiRi(:) = ZERO
       DO j=1,mole%nb_act1
         PsiRi(:) = PsiRi(:) + GG(:,j,i) * PsiRj(:,j)
       END DO
       PsiRi(:) = PsiRi(:) * Jac(:)
       !write(6,*) ' Jac Gij* ... Grid of SRep : done',iG,itab,i,OMP_GET_THREAD_NUM() ; flush(6)

       derive_termQdyn(:) = (/ mole%liste_QactTOQsym(i),0 /)

       CALL DerivOp_TO_RDP_OF_SmolaykRep(PsiRi(:),BasisnD%tab_basisPrimSG,&
                                         tab_l,tab_nq,derive_termQdyn)

       OpPsiR(:) = OpPsiR(:) + PsiRi(:)

     END DO
     !write(6,*) ' dQi Jac Gij* ... Grid of PsiR(itab) : done',itab,OMP_GET_THREAD_NUM() ; flush(6)

     OpPsiR(:) = (  -HALF*OpPsiR(:)/Jac(:) + PsiR(itab)%V(:)*V(:) ) / sqRhoOVERJac(:)
     !write(6,*) ' OpPsiR Grid of PsiR(itab)',OpPsiR
     !write(6,*) ' OpPsiR Grid of PsiR(itab) : done',itab,OMP_GET_THREAD_NUM() ; flush(6)

     !tranfert OpPsiR (on the grid) to PsiR(itab)
     PsiR(itab)%V(:) = OpPsiR(:)



     CALL dealloc_NParray(OpPsiR,'OpPsiR', name_sub)

     ! we kept PsiR(itab)%V on the grid


   END DO

   IF (allocated(PsiRi))        CALL dealloc_NParray(PsiRi,       'PsiRi',       name_sub)
   IF (allocated(PsiRj))        CALL dealloc_NParray(PsiRj,       'PsiRj',       name_sub)
   IF (allocated(tab_nb))       CALL dealloc_NParray(tab_nb,      'tab_nb',      name_sub)
   IF (allocated(tab_nq))       CALL dealloc_NParray(tab_nq,      'tab_nq',      name_sub)
   IF (allocated(tab_l))        CALL dealloc_NParray(tab_l,       'tab_l',       name_sub)

   !write(6,*) '============ END ===============' ; flush(6)
   !write(6,*) '================================' ; flush(6)

  !-----------------------------------------------------------
  IF (debug) THEN
    write(out_unitp,*) 'END ',name_sub
    CALL flush_perso(out_unitp)
  END IF
  !-----------------------------------------------------------
  !CALL UnCheck_mem() ; stop
  END SUBROUTINE sub_TabOpPsi_OF_ONEGDP_WithOp_FOR_SGtype4

  SUBROUTINE sub_TabOpPsi_OF_ONEDP_FOR_SGtype4_ompGrid(PsiR,iG,para_Op)
  USE mod_system
  USE mod_nDindex

  USE mod_Coord_KEO,               ONLY : zmatrix, get_Qact, get_d0GG

  USE mod_basis_set_alloc,         ONLY : basis
  USE mod_basis,                   ONLY : Rec_Qact_SG4
  USE mod_basis_BtoG_GtoB_SGType4, ONLY : TypeRVec,                     &
                     BDP_TO_GDP_OF_SmolyakRep,GDP_TO_BDP_OF_SmolyakRep, &
                   DerivOp_TO_RDP_OF_SmolaykRep,tabR2grid_TO_tabR1_AT_iG,&
                     getbis_tab_nq,getbis_tab_nb
  USE mod_SetOp,                      ONLY : param_Op,write_param_Op
  IMPLICIT NONE

  TYPE (TypeRVec),                    intent(inout)    :: PsiR(:)
  integer,                            intent(in)       :: iG

  TYPE (param_Op),                    intent(inout)    :: para_Op


  !local variables
  TYPE (zmatrix), pointer :: mole
  TYPE(basis),    pointer :: BasisnD

  integer :: iq,nb,nq,i,j,itab,D
  integer :: ib0,jb0,nb0,iqi,iqf,jqi,jqf

  integer                               :: derive_termQdyn(2)

  real (kind=Rkind),  allocatable       :: V(:,:,:)
  real (kind=Rkind),  allocatable       :: Qact(:)
  real (kind=Rkind),  allocatable       :: GGiq(:,:,:)
  TYPE (Type_nDindex)                   :: nDind_DPG    ! multidimensional DP index
  real (kind=Rkind),  allocatable       :: sqRhoOVERJac(:),Jac(:)
  real (kind=Rkind)                     :: Rho

  real (kind=Rkind),  allocatable       :: PsiRj(:,:),PsiRi(:),OpPsiR(:)
  real (kind=Rkind),  allocatable       :: VPsi(:,:) ! size(nq,nb0)

  integer,            allocatable       :: tab_nq(:)
  integer,            allocatable       :: tab_nb(:)
  integer,            allocatable       :: tab_l(:)
  integer :: iterm00
  integer :: err_sub,nb_thread


  !----- for debuging ----------------------------------------------
  integer :: err_mem,memory
  character (len=*), parameter :: name_sub='sub_TabOpPsi_OF_ONEDP_FOR_SGtype4_ompGrid'
  logical, parameter :: debug = .FALSE.
  !logical, parameter :: debug = .TRUE.
  !-----------------------------------------------------------------
  IF (debug) THEN
    write(out_unitp,*) 'BEGINNING ',name_sub
    write(out_unitp,*) 'nb_bie,nb_baie',para_Op%nb_bie,para_Op%nb_baie
    write(out_unitp,*) 'nb_act1',para_Op%mole%nb_act1
    write(out_unitp,*) 'nb_var',para_Op%mole%nb_var
    CALL flush_perso(out_unitp)
  END IF
  !-----------------------------------------------------------------
  !CALL Check_mem()

   !write(6,*) '================================' ; flush(6)
   !write(6,*) '============ START =============' ; flush(6)


  IF (Grid_omp == 0 .AND. OpPsi_omp > 0) THEN
    nb_thread = 1
  ELSE
    nb_thread = Grid_maxth
  END IF


   mole    => para_Op%mole
   BasisnD => para_Op%BasisnD

   D = size(BasisnD%para_SGType2%nDind_SmolyakRep%Tab_nDval,dim=1)

   CALL alloc_NParray(tab_l ,(/ D /),'tab_l', name_sub)
   CALL alloc_NParray(tab_nb,(/ D /),'tab_nb',name_sub)
   CALL alloc_NParray(tab_nq,(/ D /),'tab_nq',name_sub)

   tab_l(:)  = BasisnD%para_SGType2%nDind_SmolyakRep%Tab_nDval(:,iG)
   tab_nq(:) = getbis_tab_nq(tab_l,BasisnD%tab_basisPrimSG)
   tab_nb(:) = getbis_tab_nb(tab_l,BasisnD%tab_basisPrimSG)


   nb  = BasisnD%para_SGType2%tab_nb_OF_SRep(iG)
   nq  = BasisnD%para_SGType2%tab_nq_OF_SRep(iG)
   nb0 = BasisnD%para_SGType2%nb0

   CALL alloc_NParray(PsiRj,(/ nq,mole%nb_act1 /),'PsiRj',       name_sub)
   CALL alloc_NParray(PsiRi,       (/ nq /),      'PsiRi',       name_sub)
   CALL alloc_NParray(sqRhoOVERJac,(/ nq /),      'sqRhoOVERJac',name_sub)
   CALL alloc_NParray(Jac,         (/ nq /),      'Jac',         name_sub)


   CALL get_OpGrid_type10_OF_ONEDP_FOR_SG4(iG,tab_l,para_Op,V)

   ! G calculation
   CALL alloc_NParray(GGiq,(/nq,mole%nb_act1,mole%nb_act1/),'GGiq',name_sub)
   CALL init_nDindexPrim(nDind_DPG,BasisnD%nb_basis,tab_nq,type_OF_nDindex=-1)

 !$OMP parallel                                               &
 !$OMP default(none)                                          &
 !$OMP shared(mole,BasisnD,para_Op,nq,tab_l,nDind_DPG,iG)     &
 !$OMP shared(sqRhoOVERJac,Jac,GGiq)                          &
 !$OMP private(iq,Qact,err_sub,Rho)                           &
 !$OMP num_threads(nb_thread)
   CALL alloc_NParray(Qact,(/mole%nb_var/),'Qact',name_sub)
 !$OMP   DO SCHEDULE(STATIC)
   DO iq=1,nq
     CALL get_Qact(Qact,mole%ActiveTransfo) ! rigid, flexible coordinates
     CALL Rec_Qact_SG4(Qact,BasisnD%tab_basisPrimSG,tab_l,nDind_DPG,iq,mole,err_sub)

     CALL get_d0GG(Qact,para_Op%para_Tnum,mole,d0GG=GGiq(iq,:,:),        &
                                         def=.TRUE.,Jac=Jac(iq),Rho=Rho)
     sqRhoOVERJac(iq) = sqrt(Rho/Jac(iq))

   END DO
!$OMP   END DO
   CALL dealloc_NParray(Qact,'Qact',name_sub)
!$OMP   END PARALLEL

   CALL dealloc_nDindex(nDind_DPG)


   DO itab=1,size(PsiR)

     CALL alloc_NParray(OpPsiR,(/nq/),'OpPsiR',name_sub)

     ! partial B to G
     CALL BDP_TO_GDP_OF_SmolyakRep(PsiR(itab)%V,BasisnD%tab_basisPrimSG,&
                                   tab_l,tab_nq,tab_nb)
     ! now PsiR is on the grid
     !write(6,*) ' R Grid of PsiR(itab) :',PsiR(itab)%V
     !write(6,*) ' R Grid of PsiR(itab) : done',itab,OMP_GET_THREAD_NUM() ; flush(6)

     ! multiplication by sqRhoOVERJac
     PsiR(itab)%V(:) = PsiR(itab)%V(:) * sqRhoOVERJac(:)

     !write(6,*) ' R*sq Grid of PsiR(itab) :',PsiR
     !write(6,*) ' R*sq ... Grid of PsiR(itab) : done',itab,OMP_GET_THREAD_NUM() ; flush(6)


     ! derivative with respect to Qj
     DO j=1,mole%nb_act1
       derive_termQdyn(:) = (/ mole%liste_QactTOQsym(j),0 /)

       PsiRj(:,j) = PsiR(itab)%V(:)
       CALL DerivOp_TO_RDP_OF_SmolaykRep(PsiRj(:,j),BasisnD%tab_basisPrimSG, &
                                         tab_l,tab_nq,derive_termQdyn)

       !write(6,*) 'dQj Grid of PsiR(itab)',j,PsiRj(:,j) ; flush(6)
     END DO
     !write(6,*) ' dQj R*sq ... Grid of PsiR(itab) : done',itab,OMP_GET_THREAD_NUM() ; flush(6)

     OpPsiR(:) = ZERO
     DO i=1,mole%nb_act1

       PsiRi(:) = ZERO
       DO j=1,mole%nb_act1
         PsiRi(:) = PsiRi(:) + GGiq(:,j,i) * PsiRj(:,j)
       END DO
       PsiRi(:) = PsiRi(:) * Jac(:)
       !write(6,*) ' Jac Gij* ... Grid of SRep : done',iG,itab,i,OMP_GET_THREAD_NUM() ; flush(6)

       derive_termQdyn(:) = (/ mole%liste_QactTOQsym(i),0 /)

       CALL DerivOp_TO_RDP_OF_SmolaykRep(PsiRi(:),BasisnD%tab_basisPrimSG,&
                                         tab_l,tab_nq,derive_termQdyn)

       OpPsiR(:) = OpPsiR(:) + PsiRi(:)

     END DO
     !write(6,*) ' dQi Jac Gij* ... Grid of PsiR(itab) : done',itab,OMP_GET_THREAD_NUM() ; flush(6)

     OpPsiR(:) = (  -HALF*OpPsiR(:)/Jac(:) + PsiR(itab)%V(:)*V(:,1,1) ) / sqRhoOVERJac(:)
     !write(6,*) ' OpPsiR Grid of PsiR(itab)',OpPsiR
     !write(6,*) ' OpPsiR Grid of PsiR(itab) : done',itab,OMP_GET_THREAD_NUM() ; flush(6)

     !tranfert OpPsiR (on the grid) to PsiR(itab)
     PsiR(itab)%V(:) = OpPsiR(:)



     CALL dealloc_NParray(OpPsiR,'OpPsiR', name_sub)


     CALL GDP_TO_BDP_OF_SmolyakRep(PsiR(itab)%V,BasisnD%tab_basisPrimSG,&
                                   tab_l,tab_nq,tab_nb)
     ! now PsiR(itab)%V is on the Basis


   END DO

   IF (allocated(PsiRi))        CALL dealloc_NParray(PsiRi,       'PsiRi',       name_sub)
   IF (allocated(PsiRj))        CALL dealloc_NParray(PsiRj,       'PsiRj',       name_sub)
   IF (allocated(GGiq))         CALL dealloc_NParray(GGiq,        'GGiq',        name_sub)
   IF (allocated(tab_nb))       CALL dealloc_NParray(tab_nb,      'tab_nb',      name_sub)
   IF (allocated(tab_nq))       CALL dealloc_NParray(tab_nq,      'tab_nq',      name_sub)
   IF (allocated(tab_l))        CALL dealloc_NParray(tab_l,       'tab_l',       name_sub)
   IF (allocated(sqRhoOVERJac)) CALL dealloc_NParray(sqRhoOVERJac,'sqRhoOVERJac',name_sub)
   IF (allocated(Jac))          CALL dealloc_NParray(Jac,         'Jac',         name_sub)
   IF (allocated(V))            CALL dealloc_NParray(V,           'V',           name_sub)

   !write(6,*) '============ END ===============' ; flush(6)
   !write(6,*) '================================' ; flush(6)

  !-----------------------------------------------------------
  IF (debug) THEN
    write(out_unitp,*) 'END ',name_sub
    CALL flush_perso(out_unitp)
  END IF
  !-----------------------------------------------------------
  !CALL UnCheck_mem() ; stop
  END SUBROUTINE sub_TabOpPsi_OF_ONEDP_FOR_SGtype4_ompGrid

  SUBROUTINE get_OpGrid_type10_OF_ONEDP_FOR_SG4(iG,tab_l,para_Op,V,GGiq,sqRhoOVERJac,Jac)
  USE mod_system
  USE mod_nDindex

  USE mod_Coord_KEO,               ONLY : zmatrix, get_Qact, get_d0GG
  use mod_PrimOp,                  only: param_d0matop, init_d0matop, Get_iOp_FROM_n_Op,   &
                                         param_typeop, get_d0MatOp_AT_Qact, &
                                         dealloc_tab_of_d0matop

  USE mod_basis_set_alloc,         ONLY : basis
  USE mod_basis,                   ONLY : Rec_Qact_SG4_with_Tab_iq
  USE mod_basis_BtoG_GtoB_SGType4, ONLY : TypeRVec,                     &
                     BDP_TO_GDP_OF_SmolyakRep,GDP_TO_BDP_OF_SmolyakRep, &
                  DerivOp_TO_RDP_OF_SmolaykRep,tabR2grid_TO_tabR1_AT_iG,&
                     getbis_tab_nq,getbis_tab_nb,tabR2gridbis_TO_tabR1_AT_iG
  USE mod_SetOp,                      ONLY : param_Op,write_param_Op
  USE mod_MPI


  IMPLICIT NONE

  real (kind=Rkind),  allocatable,    intent(inout)              :: V(:,:,:)
  real (kind=Rkind),  allocatable,    intent(inout), optional    :: GGiq(:,:,:)
  real (kind=Rkind),  allocatable,    intent(inout), optional    :: sqRhoOVERJac(:),Jac(:)
  integer,                            intent(in)                 :: iG,tab_l(:)

  TYPE (param_Op),                    intent(inout)    :: para_Op

  !local variables
  TYPE (zmatrix), pointer :: mole
  TYPE(basis),    pointer :: BasisnD

  integer :: iq,nq,D

  integer                               :: derive_termQdyn(2)
  real (kind=Rkind),  allocatable       :: Qact(:)
  real (kind=Rkind)                     :: Rho

  integer,            allocatable       :: tab_nq(:)
  integer,            allocatable       :: tab_iq(:)
  integer :: iterm00,iOp,itabR,nR,nb0,i,j
  integer :: err_sub
  logical :: KEO
  logical :: lformatted=.TRUE.

  TYPE (param_d0MatOp), allocatable :: d0MatOp(:)
  character (len=Line_len) :: FileName_RV


  !----- for debuging ----------------------------------------------
  integer :: err_mem,memory
  character (len=*), parameter :: name_sub='get_OpGrid_type10_OF_ONEDP_FOR_SG4'
  logical, parameter :: debug = .FALSE.
  !logical, parameter :: debug = .TRUE.
  !-----------------------------------------------------------------
  IF (debug) THEN
    write(out_unitp,*) 'BEGINNING ',name_sub
    write(out_unitp,*) 'nb_bie,nb_baie',para_Op%nb_bie,para_Op%nb_baie
    write(out_unitp,*) 'nb_act1',para_Op%mole%nb_act1
    write(out_unitp,*) 'nb_var',para_Op%mole%nb_var
    CALL flush_perso(out_unitp)
  END IF
  !-----------------------------------------------------------------

   !write(6,*) '================================' ; flush(6)
   !write(6,*) '============ START =============' ; flush(6)

   mole    => para_Op%mole
   BasisnD => para_Op%BasisnD

   KEO = present(GGiq) .AND. present(sqRhoOVERJac) .AND.                &
         present(Jac)  .AND. para_Op%n_op == 0
   D = size(tab_l)

   CALL alloc_NParray(Qact,(/mole%nb_var/),'Qact',name_sub)
   CALL alloc_NParray(tab_nq,(/ D /),'tab_nq',name_sub)
   CALL alloc_NParray(tab_iq,(/ D /),'tab_iq',name_sub)

   tab_nq(:) = getbis_tab_nq(tab_l,BasisnD%tab_basisPrimSG)

   nq  = BasisnD%para_SGType2%tab_nq_OF_SRep(iG)
   nb0 = BasisnD%para_SGType2%nb0

   IF (KEO) THEN
     CALL alloc_NParray(sqRhoOVERJac,(/ nq /),      'sqRhoOVERJac',name_sub)
     CALL alloc_NParray(Jac,         (/ nq /),      'Jac',         name_sub)
   END IF

   !transfert part of the scalar part of the potential
   iterm00 = para_Op%derive_term_TO_iterm(0,0)
   iOp     = Get_iOp_FROM_n_Op(para_Op%n_Op) ! 2,1,2 + n_Op
   write(*,*) 'iOp check1',iOp

   lformatted = para_Op%OpGrid(iterm00)%para_FileGrid%Formatted_FileGrid

   IF (debug) THEN
     write(out_unitp,*) iG,'Save_MemGrid,Save_MemGrid_done',            &
                 para_Op%OpGrid(iterm00)%para_FileGrid%Save_MemGrid,    &
                 para_Op%OpGrid(iterm00)%para_FileGrid%Save_MemGrid_done
     write(out_unitp,*) iG,'Save_FileGrid,Save_FileGrid_done',          &
                para_Op%OpGrid(iterm00)%para_FileGrid%Save_FileGrid,    &
                para_Op%OpGrid(iterm00)%para_FileGrid%Save_FileGrid_done
   END IF

   IF (para_Op%OpGrid(iterm00)%para_FileGrid%Save_MemGrid_done) THEN
     IF (para_Op%OpGrid(iterm00)%grid_zero) THEN
       CALL alloc_NParray(V,(/ nq,nb0,nb0 /),'V',name_sub)
       V(:,:,:) = ZERO
     ELSE
       IF (para_Op%OpGrid(iterm00)%grid_cte) THEN
         CALL alloc_NParray(V,(/ nq,nb0,nb0 /),'V',name_sub)
         DO i=1,nb0
         DO j=1,nb0
           V(:,j,i) = para_Op%OpGrid(iterm00)%Mat_cte(j,i)
         END DO
         END DO
       ELSE
         CALL alloc_NParray(V,(/ nq,nb0,nb0 /),'V',name_sub)
         IF (associated(para_Op%OpGrid)) THEN
         IF (associated(para_Op%OpGrid(iterm00)%Grid)) THEN
         DO i=1,nb0
         DO j=1,nb0
           CALL tabR2gridbis_TO_tabR1_AT_iG(V(:,j,i),                   &
                                   para_Op%OpGrid(iterm00)%Grid(:,j,i), &
                                            iG,BasisnD%para_SGType2)
         END DO
         END DO
         END IF
         END IF
       END IF
     END IF

   ELSE IF (para_Op%OpGrid(iterm00)%para_FileGrid%Save_FileGrid_done .OR. &
            para_Op%OpGrid(iterm00)%para_FileGrid%Read_FileGrid) THEN
    STOP 'nb0>1 not yet'
    IF (nb0 /= 1) STOP 'nb0>1 not yet'

    !$OMP  CRITICAL (get_OpGrid_type10_OF_ONEDP_FOR_SG4_CRIT2)
     FileName_RV = trim(para_Op%OpGrid(iterm00)%file_Grid%name) // '_SGterm' // int_TO_char(iG)

     IF (iG == 1 .AND. debug) THEN
       write(out_unitp,*) 'iG,nq, FileName_RV',iG,nq,FileName_RV
       CALL flush_perso(out_unitp)
     END IF

     ! this subroutine does not work because V as 3 dim (before 1)
     !CALL sub_ReadRV(V,FileName_RV,lformatted,err_sub)
     IF (err_sub /= 0) STOP 'error while reading the grid'
     IF (nq /= size(V)) THEN
       write(out_unitp,*) ' ERROR in ',name_sub
       write(out_unitp,*) ' the size of the subroutine and file grids are different'
       write(out_unitp,*) ' nq (subroutine) and nq (file):',nq,size(V)
       write(out_unitp,*) ' file name: ',FileName_RV
       STOP
     END IF
     IF (iG == 1 .AND. debug) THEN
       write(out_unitp,*) 'iG,nq, read V',iG,nq
       CALL flush_perso(out_unitp)
     END IF

    !$OMP  END CRITICAL (get_OpGrid_type10_OF_ONEDP_FOR_SG4_CRIT2)

   ELSE IF (.NOT. para_Op%OpGrid(iterm00)%para_FileGrid%Save_MemGrid_done) THEN
     CALL alloc_NParray(V,(/ nq,nb0,nb0 /),'V',name_sub)
     allocate(d0MatOp(para_Op%para_PES%nb_scalar_Op+2))
     DO iOp=1,size(d0MatOp)
       CALL Init_d0MatOp(d0MatOp(iOp),para_Op%param_TypeOp,para_Op%para_PES%nb_elec)
     END DO
   END IF

   write(*,*) 'iOp check2',iOp

   ! G calculation
   CALL alloc_NParray(GGiq,(/nq,mole%nb_act1,mole%nb_act1/),'GGiq',name_sub)

   tab_iq(:) = 1 ; tab_iq(1) = 0

   DO iq=1,nq

     CALL ADD_ONE_TO_nDval_m1(tab_iq,tab_nq)

     CALL get_Qact(Qact,mole%ActiveTransfo) ! rigid, flexible coordinates
     CALL Rec_Qact_SG4_with_Tab_iq(Qact,BasisnD%tab_basisPrimSG,tab_l,tab_iq,mole,err_sub)

     IF (KEO) THEN
       CALL get_d0GG(Qact,para_Op%para_Tnum,mole,d0GG=GGiq(iq,:,:),     &
                                         def=.TRUE.,Jac=Jac(iq),Rho=Rho)

       sqRhoOVERJac(iq) = sqrt(Rho/Jac(iq))
     END IF

     IF (.NOT. para_Op%OpGrid(iterm00)%para_FileGrid%Save_MemGrid_done  .AND. &
         .NOT. para_Op%OpGrid(iterm00)%para_FileGrid%Save_FileGrid_done .AND. &
         .NOT. para_Op%OpGrid(iterm00)%para_FileGrid%Read_FileGrid) THEN

        CALL get_d0MatOp_AT_Qact(Qact,d0MatOp,mole,                     &
                                 para_Op%para_Tnum,para_Op%para_PES)

        write(*,*) 'iOp check3',iOp
        DO i=1,nb0
        DO j=1,nb0
          V(iq,j,i) = d0MatOp(iOp)%ReVal(j,i,iterm00)
          !was V(iq,j,i) = d0MatOp(iterm00)%ReVal(j,i,1)
          !!! iOpE= 1 (iOp) in get_d0MatOp_AT_Qact
          !!! iOpS=2 (if nb_Op=sizie(d0MatOp)>2)  (iOp) in get_d0MatOp_AT_Qact
        END DO
        END DO

        IF (iG == 1 .AND. debug) THEN
          write(out_unitp,*) 'iG,nq,V',iG,nq,V
          CALL flush_perso(out_unitp)
        END IF

     END IF

   END DO
   !IF (debug) write(out_unitp,*) 'V(:,:,:)',V(:,:,:)


   IF (para_Op%OpGrid(iterm00)%para_FileGrid%Save_MemGrid .AND.       &
     .NOT. para_Op%OpGrid(iterm00)%para_FileGrid%Save_MemGrid_done) THEN
   IF (associated(para_Op%OpGrid(iterm00)%Grid)) THEN
     itabR = BasisnD%para_SGType2%tab_Sum_nq_OF_SRep(iG)
     nR    = BasisnD%para_SGType2%tab_nq_OF_SRep(iG)
     para_Op%OpGrid(iterm00)%Grid(itabR-nR+1:itabR,:,:) = V

     IF (iG == 1 .AND. debug) THEN
       write(out_unitp,*) 'iG,nq, save mem V',iG,nq
       CALL flush_perso(out_unitp)
     END IF

   END IF
   END IF

   IF (para_Op%OpGrid(iterm00)%para_FileGrid%Save_FileGrid .AND.           &
      .NOT. para_Op%OpGrid(iterm00)%para_FileGrid%Save_FileGrid_done .AND. &
      .NOT. para_Op%OpGrid(iterm00)%para_FileGrid%Read_FileGrid) THEN
    STOP 'nb0>1 not yet'
    IF (nb0 /= 1) STOP 'nb0>1 not yet'

!    !$OMP  CRITICAL (get_OpGrid_type10_OF_ONEDP_FOR_SG4_CRIT1)
     FileName_RV = trim(para_Op%OpGrid(iterm00)%file_Grid%name) // '_SGterm' // int_TO_char(iG)

     ! this subroutine does not work because V as 3 dim (before 1)
     !CALL sub_WriteRV(V,FileName_RV,lformatted,err_sub)

     IF (iG == 1 .AND. debug) THEN
       write(out_unitp,*) 'iG,nq, save file V',iG,nq
       CALL flush_perso(out_unitp)
     END IF

!    !$OMP  END CRITICAL (get_OpGrid_type10_OF_ONEDP_FOR_SG4_CRIT1)
   END IF

  IF (allocated(tab_nq))       CALL dealloc_NParray(tab_nq,      'tab_nq',      name_sub)
  IF (allocated(tab_iq))       CALL dealloc_NParray(tab_iq,      'tab_iq',      name_sub)
  IF (allocated(Qact))         CALL dealloc_NParray(Qact,        'Qact',        name_sub)

  IF (allocated(d0MatOp)) THEN
    CALL dealloc_Tab_OF_d0MatOp(d0MatOp)
    deallocate(d0MatOp)
  END IF

   !write(6,*) '============ END ===============' ; flush(6)
   !write(6,*) '================================' ; flush(6)

  !-----------------------------------------------------------
  IF (debug) THEN
    DO i=1,nb0
    DO j=1,nb0
      write(out_unitp,*) 'V(:,j,i) ',j,i,V(:,j,i)
    END DO
    END DO
    write(out_unitp,*) 'GGiq(iq,:,:)'
    DO iq=1,nq
      CALL Write_Mat(GGiq(iq,:,:),out_unitp,6)
    END DO
    write(out_unitp,*) 'END ',name_sub
    CALL flush_perso(out_unitp)
  END IF
  !-----------------------------------------------------------
  END SUBROUTINE get_OpGrid_type10_OF_ONEDP_FOR_SG4

  SUBROUTINE get_OpGrid_type1_OF_ONEDP_FOR_SG4_new(iG,tab_l,para_Op,GridOp)
  USE mod_system
  USE mod_nDindex

  USE mod_Coord_KEO,               ONLY : zmatrix, get_Qact
  use mod_PrimOp,                  only: param_d0matop, init_d0matop, Get_iOp_FROM_n_Op,  &
                                         param_typeop, TnumKEO_TO_tab_d0H, get_d0MatOp_AT_Qact, &
                                         dealloc_tab_of_d0matop

  USE mod_basis_set_alloc,         ONLY : basis
  USE mod_basis,                   ONLY : Rec_Qact_SG4_with_Tab_iq
  USE mod_basis_BtoG_GtoB_SGType4, ONLY : TypeRVec,                     &
                     BDP_TO_GDP_OF_SmolyakRep,GDP_TO_BDP_OF_SmolyakRep, &
                  DerivOp_TO_RDP_OF_SmolaykRep,tabR2grid_TO_tabR1_AT_iG,&
                     getbis_tab_nq,getbis_tab_nb,tabR2gridbis_TO_tabR1_AT_iG
  USE mod_SetOp,                      ONLY : param_Op,write_param_Op


  IMPLICIT NONE

  real (kind=Rkind),  allocatable,    intent(inout)              :: GridOp(:,:,:,:)
  integer,                            intent(in)                 :: iG,tab_l(:)

  TYPE (param_Op),                    intent(inout)    :: para_Op

  !local variables
  TYPE (zmatrix), pointer :: mole
  TYPE(basis),    pointer :: BasisnD


  integer                               :: derive_termQdyn(2)
  real (kind=Rkind),  allocatable       :: Qact(:)

  integer,            allocatable       :: tab_nq(:)
  integer,            allocatable       :: tab_iq(:)

  integer :: iq,nq,D,iOp,iterm,iterm00,itabR,nR,nb0,i,j
  integer :: err_sub

  logical :: Op_term_done(para_Op%nb_Term)
  TYPE (param_d0MatOp), allocatable :: d0MatOp(:)
  character (len=Line_len) :: FileName_RV


  !----- for debuging ----------------------------------------------
  integer :: err_mem,memory
  character (len=*), parameter :: name_sub='get_OpGrid_type1_OF_ONEDP_FOR_SG4_new'
  logical, parameter :: debug = .FALSE.
  !logical, parameter :: debug = .TRUE.
  !-----------------------------------------------------------------
  IF (debug) THEN
    write(out_unitp,*) 'BEGINNING ',name_sub
    write(out_unitp,*) 'nb_bie,nb_baie',para_Op%nb_bie,para_Op%nb_baie
    write(out_unitp,*) 'nb_act1',para_Op%mole%nb_act1
    write(out_unitp,*) 'nb_var',para_Op%mole%nb_var
    CALL flush_perso(out_unitp)
  END IF
  !-----------------------------------------------------------------

 IF (iG == 1 .AND. debug) write(6,*) '================================' ; flush(6)
 IF (iG == 1 .AND. debug) write(6,*) '============ START =============' ; flush(6)

   mole    => para_Op%mole
   BasisnD => para_Op%BasisnD


   D = size(tab_l)

   CALL alloc_NParray(Qact,(/mole%nb_var/),'Qact',name_sub)
   CALL alloc_NParray(tab_nq,(/ D /),'tab_nq',name_sub)
   CALL alloc_NParray(tab_iq,(/ D /),'tab_iq',name_sub)

   tab_nq(:) = getbis_tab_nq(tab_l,BasisnD%tab_basisPrimSG)

   nq  = BasisnD%para_SGType2%tab_nq_OF_SRep(iG)
   nb0 = BasisnD%para_SGType2%nb0

   CALL alloc_NParray(GridOp,(/ nq,nb0,nb0,para_Op%nb_Term /),'GridOp',name_sub)
   GridOp(:,:,:,:) = ZERO
   Op_term_done(:) = .FALSE.


   !transfert part of the scalar part of the potential
   iterm00 = para_Op%derive_term_TO_iterm(0,0)
   iOp     = Get_iOp_FROM_n_Op(para_Op%n_Op)
   !write(6,*) name_sub,' iOp',iOp

   IF (debug) THEN
     write(out_unitp,*) iG,'Save_MemGrid,Save_MemGrid_done',            &
                 para_Op%OpGrid(iterm00)%para_FileGrid%Save_MemGrid,    &
                 para_Op%OpGrid(iterm00)%para_FileGrid%Save_MemGrid_done
   END IF

   IF (para_Op%OpGrid(iterm00)%para_FileGrid%Save_MemGrid_done) THEN
      IF (associated(para_Op%OpGrid)) THEN
        DO iterm=1,para_Op%nb_Term
          IF (para_Op%OpGrid(iterm)%grid_zero) THEN
            IF (debug) write(out_unitp,*) ' Op term: zero',iG,nq

            GridOp(:,:,:,iterm) = ZERO
            Op_term_done(iterm) = .TRUE.
          ELSE
            IF (para_Op%OpGrid(iterm)%grid_cte) THEN
              IF (debug) write(out_unitp,*) ' Op term: cte',iG,iterm,nq
              DO i=1,nb0
              DO j=1,nb0
                GridOp(:,j,i,iterm) = para_Op%OpGrid(iterm)%Mat_cte(j,i)
              END DO
              END DO
              Op_term_done(iterm) = .TRUE.
            ELSE
              IF (associated(para_Op%OpGrid(iterm)%Grid)) THEN
                IF (debug) write(out_unitp,*) ' Op term: from memory',iG,iterm,nq
                Op_term_done(iterm) = .TRUE.
                DO i=1,nb0
                DO j=1,nb0
                  CALL tabR2gridbis_TO_tabR1_AT_iG(GridOp(:,j,i,iterm),    &
                                        para_Op%OpGrid(iterm)%Grid(:,j,i), &
                                                  iG,BasisnD%para_SGType2)
                END DO
                END DO
              ELSE
                IF (debug) write(out_unitp,*) ' Op term: from memory SRep',iG,iterm,nq
                Op_term_done(iterm) = .TRUE.
                GridOp(:,:,:,iterm) = reshape(para_Op%OpGrid(iterm)%SRep%SmolyakRep(iG)%V,shape=[nq,nb0,nb0])
              END IF
            END IF
          END IF
        END DO
      END IF

   ELSE IF (.NOT. para_Op%OpGrid(iterm00)%para_FileGrid%Save_MemGrid_done) THEN
     allocate(d0MatOp(para_Op%para_PES%nb_scalar_Op+2))
     DO i=1,size(d0MatOp)
       CALL Init_d0MatOp(d0MatOp(i),para_Op%param_TypeOp,para_Op%para_PES%nb_elec)
     END DO

     tab_iq(:) = 1 ; tab_iq(1) = 0

     DO iq=1,nq

       CALL ADD_ONE_TO_nDval_m1(tab_iq,tab_nq)

       CALL get_Qact(Qact,mole%ActiveTransfo) ! rigid, flexible coordinates
       CALL Rec_Qact_SG4_with_Tab_iq(Qact,BasisnD%tab_basisPrimSG,tab_l,tab_iq,mole,err_sub)

       CALL get_d0MatOp_AT_Qact(Qact,d0MatOp,mole,                     &
                                   para_Op%para_Tnum,para_Op%para_PES)

       IF (para_Op%n_Op == 0) THEN ! H
         CALL TnumKEO_TO_tab_d0H(Qact,d0MatOp(iOp),mole,para_Op%para_Tnum) ! here the vep is added to the potential

         DO iterm=1,para_Op%nb_Term ! just the diagonal elements
           IF (iterm == iterm00) CYCLE ! without the vep+potential
           DO i=1,nb0
             GridOp(iq,i,i,iterm) = d0MatOp(iOp)%ReVal(i,i,iterm)
           END DO
         END DO
       END IF

       ! now the saclar part (diagonal+off diagonal elements)
       ! when Op=H, potential+vep
       GridOp(iq,:,:,iterm00) = d0MatOp(iOp)%ReVal(:,:,iterm00)

     END DO

     IF (iG == 1 .AND. debug) THEN
       write(out_unitp,*) 'iG,nq,GridOp: calc',iG,nq,GridOp(:,:,:,iterm00)
       CALL flush_perso(out_unitp)
     END IF
   END IF

   DO iterm=1,para_Op%nb_Term
     IF (para_Op%OpGrid(iterm)%para_FileGrid%Save_MemGrid .AND.           &
        .NOT. para_Op%OpGrid(iterm)%para_FileGrid%Save_MemGrid_done .AND. &
        Op_term_done(iterm) ) THEN

       IF (associated(para_Op%OpGrid(iterm)%Grid)) THEN
         itabR = BasisnD%para_SGType2%tab_Sum_nq_OF_SRep(iG)
         nR    = BasisnD%para_SGType2%tab_nq_OF_SRep(iG)

         IF (iG == 1 .AND. debug) write(out_unitp,*) 'iG,nq,GridOp: save mem Grid',iterm


         para_Op%OpGrid(iterm00)%Grid(itabR-nR+1:itabR,:,:) = GridOp(:,:,:,iterm)
         para_Op%OpGrid(iterm)%grid_zero = .FALSE.
         para_Op%OpGrid(iterm)%grid_cte  = .FALSE.

       ELSE IF (allocated(para_Op%OpGrid(iterm)%SRep%SmolyakRep)) THEN
         IF (iG == 1 .AND. debug) write(out_unitp,*) 'iG,nq,GridOp SRep: save mem Grid',iterm

         para_Op%OpGrid(iterm)%SRep%SmolyakRep(iG)%V = reshape(GridOp(:,:,:,iterm),shape=[nq*nb0**2])
         para_Op%OpGrid(iterm)%grid_zero = .FALSE.
         para_Op%OpGrid(iterm)%grid_cte  = .FALSE.
       END IF

       IF (iG == 1 .AND. debug) THEN
         write(out_unitp,*) 'iG,nq, save mem GridOp',iG,nq
         CALL flush_perso(out_unitp)
       END IF

     END IF

   END DO


  IF (allocated(tab_nq))       CALL dealloc_NParray(tab_nq,      'tab_nq',      name_sub)
  IF (allocated(tab_iq))       CALL dealloc_NParray(tab_iq,      'tab_iq',      name_sub)
  IF (allocated(Qact))         CALL dealloc_NParray(Qact,        'Qact',        name_sub)

  IF (allocated(d0MatOp)) THEN
    CALL dealloc_Tab_OF_d0MatOp(d0MatOp)
    deallocate(d0MatOp)
  END IF

 IF (iG == 1 .AND. debug)  write(6,*) '============ END ===============' ; flush(6)
 IF (iG == 1 .AND. debug)  write(6,*) '================================' ; flush(6)

  !-----------------------------------------------------------
  IF (debug) THEN
    DO iterm=1,para_Op%nb_Term
      write(out_unitp,*) 'GridOp(:,:,:,iterm)',iterm,GridOp(:,:,:,iterm)
    END DO
    write(out_unitp,*) 'END ',name_sub
    CALL flush_perso(out_unitp)
  END IF
  !-----------------------------------------------------------
  END SUBROUTINE get_OpGrid_type1_OF_ONEDP_FOR_SG4_new

!=======================================================================================
! new2 get_OpGrid_type1_OF_ONEDP_FOR_SG4 added SmolyakRep part  
  SUBROUTINE get_OpGrid_type1_OF_ONEDP_FOR_SG4_new2(iG,tab_l,para_Op,GridOp)
  USE mod_system
  USE mod_nDindex

  USE mod_Coord_KEO,               ONLY : zmatrix, get_Qact
  use mod_PrimOp,                  ONLY : param_d0matop, init_d0matop, Get_iOp_FROM_n_Op,  &
                                          param_typeop, TnumKEO_TO_tab_d0H, get_d0MatOp_AT_Qact, &
                                          dealloc_tab_of_d0matop

  USE mod_basis_set_alloc,         ONLY : basis
  USE mod_basis,                   ONLY : Rec_Qact_SG4_with_Tab_iq
  USE mod_basis_BtoG_GtoB_SGType4, ONLY : TypeRVec,                     &
                     BDP_TO_GDP_OF_SmolyakRep,GDP_TO_BDP_OF_SmolyakRep, &
                  DerivOp_TO_RDP_OF_SmolaykRep,tabR2grid_TO_tabR1_AT_iG,&
                     getbis_tab_nq,getbis_tab_nb,tabR2gridbis_TO_tabR1_AT_iG
  USE mod_SetOp,                      ONLY : param_Op,write_param_Op
  USE mod_MPI
  IMPLICIT NONE

  real (kind=Rkind),  allocatable,    intent(inout)              :: GridOp(:,:,:,:)
  integer,                            intent(in)                 :: iG,tab_l(:)

  TYPE (param_Op),                    intent(inout)    :: para_Op

  !local variables
  TYPE (zmatrix), pointer :: mole
  TYPE(basis),    pointer :: BasisnD


  integer                               :: derive_termQdyn(2)
  real (kind=Rkind),  allocatable       :: Qact(:)

  integer,            allocatable       :: tab_nq(:)
  integer,            allocatable       :: tab_iq(:)

  integer :: iq,nq,D,iOp,iterm,iterm00,itabR,nR,nb0,i,j
  integer :: err_sub

  logical :: KEO_done,Op_term_done(para_Op%nb_Term)
  TYPE (param_d0MatOp), allocatable :: d0MatOp(:)
  character (len=Line_len) :: FileName_RV


  !----- for debuging ----------------------------------------------
  integer :: err_mem,memory
  character (len=*), parameter :: name_sub='get_OpGrid_type1_OF_ONEDP_FOR_SG4_new2'
  logical, parameter :: debug = .FALSE.
  !logical, parameter :: debug = .TRUE.
  !-----------------------------------------------------------------
  IF (debug) THEN
    write(out_unitp,*) 'BEGINNING ',name_sub
    write(out_unitp,*) 'nb_bie,nb_baie',para_Op%nb_bie,para_Op%nb_baie
    write(out_unitp,*) 'nb_act1',para_Op%mole%nb_act1
    write(out_unitp,*) 'nb_var',para_Op%mole%nb_var
    CALL flush_perso(out_unitp)
  END IF
  !-----------------------------------------------------------------

 IF (iG == 1 .AND. debug) write(6,*) '================================' ; flush(6)
 IF (iG == 1 .AND. debug) write(6,*) '============ START =============' ; flush(6)

   mole    => para_Op%mole
   BasisnD => para_Op%BasisnD


   D = size(tab_l)

   CALL alloc_NParray(Qact,(/mole%nb_var/),'Qact',name_sub)
   CALL alloc_NParray(tab_nq,(/ D /),'tab_nq',name_sub)
   CALL alloc_NParray(tab_iq,(/ D /),'tab_iq',name_sub)

   tab_nq(:) = getbis_tab_nq(tab_l,BasisnD%tab_basisPrimSG)

   nq  = BasisnD%para_SGType2%tab_nq_OF_SRep(iG)
   nb0 = BasisnD%para_SGType2%nb0

   CALL alloc_NParray(GridOp,(/ nq,nb0,nb0,para_Op%nb_Term /),'GridOp',name_sub)
   GridOp(:,:,:,:) = ZERO
   Op_term_done(:) = .FALSE.


   !transfert part of the scalar part of the potential
   iterm00 = para_Op%derive_term_TO_iterm(0,0)
   iOp     = Get_iOp_FROM_n_Op(para_Op%n_Op)
   !write(6,*) name_sub,' iOp',iOp

   IF (iG == 1 .AND. debug) THEN
     write(out_unitp,*) iG,'Save_MemGrid,Save_MemGrid_done',            &
                 para_Op%OpGrid(iterm00)%para_FileGrid%Save_MemGrid,    &
                 para_Op%OpGrid(iterm00)%para_FileGrid%Save_MemGrid_done
   END IF

   !first deal with constant or zero term.
   KEO_done = .TRUE.
   DO iterm=1,para_Op%nb_Term

     IF (para_Op%OpGrid(iterm)%grid_zero) THEN
       IF (iG == 1 .AND. debug) write(out_unitp,*) ' Op term: zero',iG,nq

       GridOp(:,:,:,iterm) = ZERO
       Op_term_done(iterm) = .TRUE.
     ELSE IF (para_Op%OpGrid(iterm)%grid_cte) THEN
       IF (iG == 1 .AND. debug) write(out_unitp,*) ' Op term: cte',iG,iterm,nq
       DO i=1,nb0
       DO j=1,nb0
           GridOp(:,j,i,iterm) = para_Op%OpGrid(iterm)%Mat_cte(j,i)
       END DO
         END DO
         Op_term_done(iterm) = .TRUE.
     END IF
     IF (iterm00 /= iterm) KEO_done = KEO_done .AND. Op_term_done(iterm)
   END DO
   ! Now KEO_done=.TRUE., when all KEO terms have been treated

   IF (para_Op%OpGrid(iterm00)%para_FileGrid%Save_MemGrid_done) THEN
      IF (associated(para_Op%OpGrid)) THEN
        DO iterm=1,para_Op%nb_Term
          IF (Op_term_done(iterm)) CYCLE

          IF (associated(para_Op%OpGrid(iterm)%Grid)) THEN
            IF (iG == 1 .AND. debug) write(out_unitp,*) ' Op term: from memory',iG,iterm,nq
            Op_term_done(iterm) = .TRUE.
            DO i=1,nb0
            DO j=1,nb0
              CALL tabR2gridbis_TO_tabR1_AT_iG(GridOp(:,j,i,iterm),     &
                                     para_Op%OpGrid(iterm)%Grid(:,j,i), &
                                                iG,BasisnD%para_SGType2)
            END DO
            END DO
          ELSE
            IF (iG == 1 .AND. debug) write(out_unitp,*) ' Op term: from memory SRep',iG,iterm,nq
            Op_term_done(iterm) = .TRUE.
            GridOp(:,:,:,iterm) = reshape(para_Op%OpGrid(iterm)%SRep%SmolyakRep(iG)%V,shape=[nq,nb0,nb0])
          END IF

          IF (iG == 1 .AND. debug) THEN
            write(out_unitp,*) 'iG,nq,GridOp: from mem',iG,nq,GridOp(:,:,:,iterm)
            CALL flush_perso(out_unitp)
          END IF

        END DO
      END IF

   ELSE IF (.NOT. para_Op%OpGrid(iterm00)%para_FileGrid%Save_MemGrid_done) THEN
     allocate(d0MatOp(para_Op%para_PES%nb_scalar_Op+2))
     DO i=1,size(d0MatOp)
       CALL Init_d0MatOp(d0MatOp(i),para_Op%param_TypeOp,para_Op%para_PES%nb_elec)
     END DO

     tab_iq(:) = 1 ; tab_iq(1) = 0

     DO iq=1,nq

       CALL ADD_ONE_TO_nDval_m1(tab_iq,tab_nq)

       CALL get_Qact(Qact,mole%ActiveTransfo) ! rigid, flexible coordinates
       CALL Rec_Qact_SG4_with_Tab_iq(Qact,BasisnD%tab_basisPrimSG,tab_l,tab_iq,mole,err_sub)

       CALL get_d0MatOp_AT_Qact(Qact,d0MatOp,mole,                     &
                                   para_Op%para_Tnum,para_Op%para_PES)

       IF (para_Op%n_Op == 0 .AND. .NOT. KEO_done) THEN ! H
         CALL TnumKEO_TO_tab_d0H(Qact,d0MatOp(iOp),mole,para_Op%para_Tnum) ! here the vep is added to the potential

         DO iterm=1,para_Op%nb_Term ! just the diagonal elements
           IF (iterm == iterm00) CYCLE ! without the vep+potential
           DO i=1,nb0
             GridOp(iq,i,i,iterm) = d0MatOp(iOp)%ReVal(i,i,iterm)
           END DO
         END DO
       END IF

       ! now the saclar part (diagonal+off diagonal elements)
       ! when Op=H, potential+vep
       GridOp(iq,:,:,iterm00) = d0MatOp(iOp)%ReVal(:,:,iterm00)

     END DO

     Op_term_done(:) = .TRUE.


     IF (iG == 1 .AND. debug) THEN
       write(out_unitp,*) 'iG,nq,GridOp: calc',iG,nq,GridOp(:,:,:,iterm00)
       CALL flush_perso(out_unitp)
     END IF
   END IF

   DO iterm=1,para_Op%nb_Term
     IF (para_Op%OpGrid(iterm)%para_FileGrid%Save_MemGrid .AND.           &
        .NOT. para_Op%OpGrid(iterm)%para_FileGrid%Save_MemGrid_done .AND. &
        Op_term_done(iterm) ) THEN

       IF (associated(para_Op%OpGrid(iterm)%Grid)) THEN
         itabR = BasisnD%para_SGType2%tab_Sum_nq_OF_SRep(iG)
         nR    = BasisnD%para_SGType2%tab_nq_OF_SRep(iG)

         IF (iG == 1 .AND. debug) write(out_unitp,*) 'iG,nq,GridOp: save mem Grid',iterm


         para_Op%OpGrid(iterm)%Grid(itabR-nR+1:itabR,:,:) = GridOp(:,:,:,iterm)
         para_Op%OpGrid(iterm)%grid_zero = .FALSE.
         para_Op%OpGrid(iterm)%grid_cte  = .FALSE.

         IF (iG == 1 .AND. debug) THEN
           write(out_unitp,*) 'iG,nq,GridOp: save mem Grid',iG,nq,para_Op%OpGrid(iterm)%Grid(itabR-nR+1:itabR,:,:)
           CALL flush_perso(out_unitp)
         END IF

       ELSE IF (allocated(para_Op%OpGrid(iterm)%SRep%SmolyakRep)) THEN
         IF (iG == 1 .AND. debug) write(out_unitp,*) 'iG,nq,GridOp SRep: save mem Grid',iterm

         para_Op%OpGrid(iterm)%SRep%SmolyakRep(iG)%V = reshape(GridOp(:,:,:,iterm),shape=[nq*nb0**2])
         para_Op%OpGrid(iterm)%grid_zero = .FALSE.
         para_Op%OpGrid(iterm)%grid_cte  = .FALSE.

         IF (iG == 1 .AND. debug) THEN
           write(out_unitp,*) 'iG,nq,GridOp: save mem Grid',iG,nq,para_Op%OpGrid(iterm)%SRep%SmolyakRep(iG)%V
           CALL flush_perso(out_unitp)
         END IF

       END IF


     END IF

   END DO


  IF (allocated(tab_nq))       CALL dealloc_NParray(tab_nq,      'tab_nq',      name_sub)
  IF (allocated(tab_iq))       CALL dealloc_NParray(tab_iq,      'tab_iq',      name_sub)
  IF (allocated(Qact))         CALL dealloc_NParray(Qact,        'Qact',        name_sub)

  IF (allocated(d0MatOp)) THEN
    CALL dealloc_Tab_OF_d0MatOp(d0MatOp)
    deallocate(d0MatOp)
  END IF

 IF (iG == 1 .AND. debug)  write(6,*) '============ END ===============' ; flush(6)
 IF (iG == 1 .AND. debug)  write(6,*) '================================' ; flush(6)

  !-----------------------------------------------------------
  IF (debug) THEN
    !DO iterm=1,para_Op%nb_Term
    !  write(out_unitp,*) 'GridOp(:,:,:,iterm)',iterm,GridOp(:,:,:,iterm)
    !END DO
    write(out_unitp,*) 'END ',name_sub
    CALL flush_perso(out_unitp)
  END IF
  !-----------------------------------------------------------
  END SUBROUTINE get_OpGrid_type1_OF_ONEDP_FOR_SG4_new2
!=======================================================================================

  SUBROUTINE get_OpGrid_type1_OF_ONEDP_FOR_SG4(iG,tab_l,para_Op,GridOp)
  USE mod_system
  USE mod_nDindex

  USE mod_Coord_KEO
  use mod_PrimOp

  USE mod_basis_set_alloc
  USE mod_basis
  USE mod_basis_BtoG_GtoB_SGType4
  USE mod_SetOp


  IMPLICIT NONE

  real(kind=Rkind), allocatable,      intent(inout)    :: GridOp(:,:,:,:)
  integer,                            intent(in)       :: iG,tab_l(:)
  TYPE (param_Op),                    intent(inout)    :: para_Op

  !local variables
  TYPE (zmatrix), pointer :: mole
  TYPE(basis),    pointer :: BasisnD

  integer :: iq,nq,D,iOp

  integer                               :: derive_termQdyn(2)
  real (kind=Rkind),  allocatable       :: Qact(:)

  integer,            allocatable       :: tab_nq(:)
  integer,            allocatable       :: tab_iq(:)
  integer :: iterm,iterm00,itabR,nR,nb0,i,j
  integer :: err_sub
  logical :: KEO
  logical :: Op_term_done(para_Op%nb_Term)

  TYPE (param_d0MatOp), allocatable :: d0MatOp(:)


  !----- for debuging ----------------------------------------------
  integer :: err_mem,memory
  character (len=*), parameter :: name_sub='get_OpGrid_type1_OF_ONEDP_FOR_SG4'
  logical, parameter :: debug = .FALSE.
  !logical, parameter :: debug = .TRUE.
  !-----------------------------------------------------------------
  IF (debug) THEN
    write(out_unitp,*) 'BEGINNING ',name_sub
    write(out_unitp,*) 'nb_bie,nb_baie',para_Op%nb_bie,para_Op%nb_baie
    write(out_unitp,*) 'nb_act1',para_Op%mole%nb_act1
    write(out_unitp,*) 'nb_Term',para_Op%nb_Term
    write(out_unitp,*) 'asso OpGrid',associated(para_Op%OpGrid)

    CALL flush_perso(out_unitp)
  END IF
  !-----------------------------------------------------------------

   !write(6,*) '================================' ; flush(6)
   !write(6,*) '============ START =============' ; flush(6)

   mole    => para_Op%mole
   BasisnD => para_Op%BasisnD

   D = size(tab_l)

   nq  = BasisnD%para_SGType2%tab_nq_OF_SRep(iG)
   nb0 = BasisnD%para_SGType2%nb0
   iterm00 = para_Op%derive_term_TO_iterm(0,0)
   !write(6,*) 'coucou',iG,nq


   IF (debug) THEN
     write(out_unitp,*) iG,'Save_MemGrid,Save_MemGrid_done',            &
                       para_Op%OpGrid(1)%para_FileGrid%Save_MemGrid,    &
                       para_Op%OpGrid(1)%para_FileGrid%Save_MemGrid_done
   END IF

   CALL alloc_NParray(GridOp,(/ nq,nb0,nb0,para_Op%nb_Term /),'GridOp',name_sub)
   Op_term_done(:) = .FALSE.

   IF (associated(para_Op%OpGrid)) THEN
     DO iterm=1,para_Op%nb_Term
       IF (para_Op%OpGrid(iterm)%grid_zero) THEN
         IF (debug) write(out_unitp,*) ' Op term: zero',iG,nq

         GridOp(:,:,:,iterm) = ZERO
         Op_term_done(iterm) = .TRUE.
       ELSE
         IF (para_Op%OpGrid(iterm)%grid_cte) THEN
           IF (debug) write(out_unitp,*) ' Op term: cte',iG,nq
           DO i=1,nb0
           DO j=1,nb0
             GridOp(:,j,i,iterm) = para_Op%OpGrid(iterm)%Mat_cte(j,i)
           END DO
           END DO
           Op_term_done(iterm) = .TRUE.
         ELSE
           IF (associated(para_Op%OpGrid(iterm)%Grid)) THEN
           IF (debug) write(out_unitp,*) ' Op term: from memory',iG,nq

             Op_term_done(iterm) = .TRUE.
             DO i=1,nb0
             DO j=1,nb0
               CALL tabR2gridbis_TO_tabR1_AT_iG(GridOp(:,j,i,iterm),    &
                                     para_Op%OpGrid(iterm)%Grid(:,j,i), &
                                               iG,BasisnD%para_SGType2)
             END DO
             END DO
           END IF
         END IF
       END IF
     END DO
   END IF

   !Op_term_done(iterm00) = .TRUE.
   IF (.NOT. Op_term_done(iterm00)) THEN
     IF (debug) write(out_unitp,*) ' Op term (potential): calculated',iG,nq
     write(out_unitp,*) ' Op term (potential): calculated',iG,nq

     CALL alloc_NParray(Qact,(/mole%nb_var/),'Qact',name_sub)
     CALL alloc_NParray(tab_nq,(/ D /),'tab_nq',name_sub)
     CALL alloc_NParray(tab_iq,(/ D /),'tab_iq',name_sub)

     tab_nq(:) = getbis_tab_nq(tab_l,BasisnD%tab_basisPrimSG)

     allocate(d0MatOp(para_Op%para_PES%nb_scalar_Op+2))
     DO iOp=1,size(d0MatOp)
       CALL Init_d0MatOp(d0MatOp(iOp),para_Op%param_TypeOp,para_Op%para_PES%nb_elec)
     END DO

     tab_iq(:) = 1 ; tab_iq(1) = 0

     DO iq=1,nq

       CALL ADD_ONE_TO_nDval_m1(tab_iq,tab_nq)

       CALL get_Qact(Qact,mole%ActiveTransfo) ! rigid, flexible coordinates
       CALL Rec_Qact_SG4_with_Tab_iq(Qact,BasisnD%tab_basisPrimSG,tab_l,tab_iq,mole,err_sub)

!       IF (KEO) THEN
!         CALL get_d0GG(Qact,para_Op%para_Tnum,mole,d0GG=GGiq(iq,:,:),  &
!                                        def=.TRUE.,Jac=Jac(iq),Rho=Rho)
!       END IF

          CALL get_d0MatOp_AT_Qact(Qact,d0MatOp,mole,                   &
                                   para_Op%para_Tnum,para_Op%para_PES)
          GridOp(iq,:,:,iterm00) = d0MatOp(iterm00)%ReVal(:,:,1)

     END DO

     IF (allocated(tab_nq))  CALL dealloc_NParray(tab_nq,'tab_nq',name_sub)
     IF (allocated(tab_iq))  CALL dealloc_NParray(tab_iq,'tab_iq',name_sub)
     IF (allocated(Qact))    CALL dealloc_NParray(Qact,  'Qact',  name_sub)

     IF (allocated(d0MatOp)) THEN
       CALL dealloc_Tab_OF_d0MatOp(d0MatOp)
       deallocate(d0MatOp)
     END IF

   END IF


  !write(6,*) '============ END ===============' ; flush(6)
  !write(6,*) '================================' ; flush(6)

  !-----------------------------------------------------------
  IF (debug) THEN
    DO iterm=1,para_Op%nb_Term
      write(out_unitp,*) 'GridOp(:,:,:,iterm)',iterm,GridOp(:,:,:,iterm)
    END DO
    write(out_unitp,*) 'END ',name_sub
    CALL flush_perso(out_unitp)
  END IF
  !-----------------------------------------------------------
  END SUBROUTINE get_OpGrid_type1_OF_ONEDP_FOR_SG4
!=======================================================================================

  SUBROUTINE get_OpGrid_type0_OF_ONEDP_FOR_SG4(iG,tab_l,para_Op,V)
  USE mod_system
  USE mod_nDindex

  USE mod_Coord_KEO,               ONLY : zmatrix, get_Qact
  use mod_PrimOp,                  only: param_d0matop, init_d0matop,   &
                                         param_typeop, get_d0MatOp_AT_Qact, &
                                         dealloc_tab_of_d0matop

  USE mod_basis_set_alloc,         ONLY : basis
  USE mod_basis,                   ONLY : Rec_Qact_SG4_with_Tab_iq
  USE mod_basis_BtoG_GtoB_SGType4, ONLY : TypeRVec,                     &
                     BDP_TO_GDP_OF_SmolyakRep,GDP_TO_BDP_OF_SmolyakRep, &
                  DerivOp_TO_RDP_OF_SmolaykRep,tabR2grid_TO_tabR1_AT_iG,&
                     getbis_tab_nq,getbis_tab_nb,tabR2gridbis_TO_tabR1_AT_iG
  USE mod_SetOp,                   ONLY : param_Op,write_param_Op


  IMPLICIT NONE

  real (kind=Rkind),  allocatable,    intent(inout)    :: V(:,:,:)
  integer,                            intent(in)       :: iG,tab_l(:)

  TYPE (param_Op),                    intent(inout)    :: para_Op

  !local variables
  TYPE (zmatrix), pointer :: mole
  TYPE(basis),    pointer :: BasisnD

  integer :: iq,nq,D,iOp

  integer                               :: derive_termQdyn(2)
  real (kind=Rkind),  allocatable       :: Qact(:)
  real (kind=Rkind)                     :: Rho

  integer,            allocatable       :: tab_nq(:)
  integer,            allocatable       :: tab_iq(:)
  integer :: iterm00,itabR,nR,nb0,i,j
  integer :: err_sub
  logical :: lformatted=.TRUE.

  TYPE (param_d0MatOp), allocatable :: d0MatOp(:)
  character (len=Line_len) :: FileName_RV


  !----- for debuging ----------------------------------------------
  integer :: err_mem,memory
  character (len=*), parameter :: name_sub='get_OpGrid_type0_OF_ONEDP_FOR_SG4'
  logical, parameter :: debug = .FALSE.
  !logical, parameter :: debug = .TRUE.
  !-----------------------------------------------------------------
  IF (debug) THEN
    write(out_unitp,*) 'BEGINNING ',name_sub
    write(out_unitp,*) 'nb_bie,nb_baie',para_Op%nb_bie,para_Op%nb_baie
    write(out_unitp,*) 'nb_act1',para_Op%mole%nb_act1
    write(out_unitp,*) 'nb_var',para_Op%mole%nb_var
    CALL flush_perso(out_unitp)
  END IF
  !-----------------------------------------------------------------

   !write(6,*) '================================' ; flush(6)
   !write(6,*) '============ START =============' ; flush(6)

   mole    => para_Op%mole
   BasisnD => para_Op%BasisnD

   D = size(tab_l)

   CALL alloc_NParray(Qact,(/mole%nb_var/),'Qact',name_sub)
   CALL alloc_NParray(tab_nq,(/ D /),'tab_nq',name_sub)
   CALL alloc_NParray(tab_iq,(/ D /),'tab_iq',name_sub)

   tab_nq(:) = getbis_tab_nq(tab_l,BasisnD%tab_basisPrimSG)

   nq  = BasisnD%para_SGType2%tab_nq_OF_SRep(iG)
   nb0 = BasisnD%para_SGType2%nb0


   !transfert part of the scalar part of the potential
   iterm00 = para_Op%derive_term_TO_iterm(0,0)

   lformatted = para_Op%OpGrid(iterm00)%para_FileGrid%Formatted_FileGrid

   IF (debug) THEN
     write(out_unitp,*) iG,'Save_MemGrid,Save_MemGrid_done',            &
                 para_Op%OpGrid(iterm00)%para_FileGrid%Save_MemGrid,    &
                 para_Op%OpGrid(iterm00)%para_FileGrid%Save_MemGrid_done
     write(out_unitp,*) iG,'Save_FileGrid,Save_FileGrid_done',          &
                para_Op%OpGrid(iterm00)%para_FileGrid%Save_FileGrid,    &
                para_Op%OpGrid(iterm00)%para_FileGrid%Save_FileGrid_done
   END IF

   IF (para_Op%OpGrid(iterm00)%para_FileGrid%Save_MemGrid_done) THEN
     IF (para_Op%OpGrid(iterm00)%grid_zero) THEN
       CALL alloc_NParray(V,(/ nq,nb0,nb0 /),'V',name_sub)
       V(:,:,:) = ZERO
     ELSE
       IF (para_Op%OpGrid(iterm00)%grid_cte) THEN
         CALL alloc_NParray(V,(/ nq,nb0,nb0 /),'V',name_sub)
         DO i=1,nb0
         DO j=1,nb0
            V(:,j,i) = para_Op%OpGrid(iterm00)%Mat_cte(j,i)
         END DO
         END DO
       ELSE
         IF (associated(para_Op%OpGrid)) THEN
         IF (associated(para_Op%OpGrid(iterm00)%Grid)) THEN
         CALL alloc_NParray(V,(/ nq,nb0,nb0 /),'V',name_sub)
           DO i=1,nb0
           DO j=1,nb0
             CALL tabR2gridbis_TO_tabR1_AT_iG(V(:,j,i),                 &
                                   para_Op%OpGrid(iterm00)%Grid(:,j,i), &
                                               iG,BasisnD%para_SGType2)
           END DO
           END DO
         END IF
         END IF
       END IF
     END IF
   ELSE IF (para_Op%OpGrid(iterm00)%para_FileGrid%Save_FileGrid_done .OR. &
            para_Op%OpGrid(iterm00)%para_FileGrid%Read_FileGrid) THEN
    STOP 'nb0>1 not yet'

     !$OMP  CRITICAL (get_OpGrid_type0_OF_ONEDP_FOR_SG4_CRIT2)
     FileName_RV = trim(para_Op%OpGrid(iterm00)%file_Grid%name) // '_SGterm' // int_TO_char(iG)

     IF (iG == 1 .AND. debug) THEN
       write(out_unitp,*) 'iG,nq, FileName_RV',iG,nq,FileName_RV
       CALL flush_perso(out_unitp)
     END IF

     ! the rank of V is 3 now, this subroutine work with rank 1
     !CALL sub_ReadRV(V,FileName_RV,lformatted,err_sub)
     IF (err_sub /= 0) STOP 'error while reading the grid'
     IF (nq /= size(V)) THEN
       write(out_unitp,*) ' ERROR in ',name_sub
       write(out_unitp,*) ' the size of the subroutine and file grids are different'
       write(out_unitp,*) ' nq (subroutine) and nq (file):',nq,size(V)
       write(out_unitp,*) ' file name: ',FileName_RV
       STOP
     END IF
     IF (iG == 1 .AND. debug) THEN
       write(out_unitp,*) 'iG,nq, read V',iG,nq
       CALL flush_perso(out_unitp)
     END IF
     !$OMP  END CRITICAL (get_OpGrid_type0_OF_ONEDP_FOR_SG4_CRIT2)

   ELSE IF (.NOT. para_Op%OpGrid(iterm00)%para_FileGrid%Save_MemGrid_done) THEN
     CALL alloc_NParray(V,(/ nq,nb0,nb0 /),'V',name_sub)
     allocate(d0MatOp(para_Op%para_PES%nb_scalar_Op+2))
     DO iOp=1,size(d0MatOp)
       CALL Init_d0MatOp(d0MatOp(iOp),para_Op%param_TypeOp,para_Op%para_PES%nb_elec)
     END DO
   END IF

   tab_iq(:) = 1 ; tab_iq(1) = 0

   DO iq=1,nq

     CALL ADD_ONE_TO_nDval_m1(tab_iq,tab_nq)

     CALL get_Qact(Qact,mole%ActiveTransfo) ! rigid, flexible coordinates
     CALL Rec_Qact_SG4_with_Tab_iq(Qact,BasisnD%tab_basisPrimSG,tab_l,tab_iq,mole,err_sub)

     IF (.NOT. para_Op%OpGrid(iterm00)%para_FileGrid%Save_MemGrid_done  .AND. &
         .NOT. para_Op%OpGrid(iterm00)%para_FileGrid%Save_FileGrid_done .AND. &
         .NOT. para_Op%OpGrid(iterm00)%para_FileGrid%Read_FileGrid) THEN

        CALL get_d0MatOp_AT_Qact(Qact,d0MatOp,mole,                     &
                                 para_Op%para_Tnum,para_Op%para_PES)
        V(iq,:,:) = d0MatOp(iterm00)%ReVal(:,:,1)

        IF (iG == 1 .AND. debug) THEN
          write(out_unitp,*) 'iG,nq,V',iG,nq,V
          CALL flush_perso(out_unitp)
        END IF

     END IF

   END DO


   IF (para_Op%OpGrid(iterm00)%para_FileGrid%Save_MemGrid .AND.       &
     .NOT. para_Op%OpGrid(iterm00)%para_FileGrid%Save_MemGrid_done) THEN
   IF (associated(para_Op%OpGrid(iterm00)%Grid)) THEN
     itabR = BasisnD%para_SGType2%tab_Sum_nq_OF_SRep(iG)
     nR    = BasisnD%para_SGType2%tab_nq_OF_SRep(iG)
     para_Op%OpGrid(iterm00)%Grid(itabR-nR+1:itabR,:,:) = V(:,:,:)

     IF (iG == 1 .AND. debug) THEN
       write(out_unitp,*) 'iG,nq, save mem V',iG,nq
       CALL flush_perso(out_unitp)
     END IF

   END IF
   END IF

   IF (para_Op%OpGrid(iterm00)%para_FileGrid%Save_FileGrid .AND.           &
      .NOT. para_Op%OpGrid(iterm00)%para_FileGrid%Save_FileGrid_done .AND. &
      .NOT. para_Op%OpGrid(iterm00)%para_FileGrid%Read_FileGrid) THEN
    STOP 'nb0>1 not yet'

!    !$OMP  CRITICAL (get_OpGrid_type0_OF_ONEDP_FOR_SG4_CRIT1)
     FileName_RV = trim(para_Op%OpGrid(iterm00)%file_Grid%name) // '_SGterm' // int_TO_char(iG)

     ! the rank of V is 3 now, this subroutine work with rank 1
     !CALL sub_WriteRV(V,FileName_RV,lformatted,err_sub)

     IF (iG == 1 .AND. debug) THEN
       write(out_unitp,*) 'iG,nq, save file V',iG,nq
       CALL flush_perso(out_unitp)
     END IF

!    !$OMP  END CRITICAL (get_OpGrid_type0_OF_ONEDP_FOR_SG4_CRIT1)
   END IF

  IF (allocated(tab_nq))       CALL dealloc_NParray(tab_nq,      'tab_nq',      name_sub)
  IF (allocated(tab_iq))       CALL dealloc_NParray(tab_iq,      'tab_iq',      name_sub)
  IF (allocated(Qact))         CALL dealloc_NParray(Qact,        'Qact',        name_sub)

  IF (allocated(d0MatOp)) THEN
    CALL dealloc_Tab_OF_d0MatOp(d0MatOp)
    deallocate(d0MatOp)
  END IF

   !write(6,*) '============ END ===============' ; flush(6)
   !write(6,*) '================================' ; flush(6)

  !-----------------------------------------------------------
  IF (debug) THEN
    write(out_unitp,*) 'END ',name_sub
    CALL flush_perso(out_unitp)
  END IF
  !-----------------------------------------------------------
  END SUBROUTINE get_OpGrid_type0_OF_ONEDP_FOR_SG4

END MODULE mod_OpPsi_SG4
